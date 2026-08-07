// Main infrastructure orchestration for Open WebUI + LiteLLM on Azure Container Apps
// This template follows Azure Developer CLI (azd) conventions

targetScope = 'subscription'

@minLength(3)
@maxLength(24)
@description('Name of the environment (e.g., dev, prod) used to generate resource names')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('LiteLLM Master Key for API authentication')
@secure()
param litellmMasterKey string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

// Tags for all resources
var tags = {
  'azd-env-name': environmentName
  app: 'openwebui-litellm'
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

var aiServicesAccountName = 'aif-${environmentName}-${uniqueString(rg.id)}'
var aiProjectName = 'proj-${environmentName}'

module network './core/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    tags: tags
    vnetName: 'vnet-${environmentName}'
  }
}

// Foundry provides a self-contained model platform for this app and future
// Foundry Agents workloads.
module foundry './core/foundry.bicep' = {
  name: 'foundry'
  scope: rg
  params: {
    location: location
    tags: tags
    accountName: aiServicesAccountName
    projectName: aiProjectName
  }
}

// Core infrastructure: Log Analytics using AVM
module monitoring 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: 'monitoring'
  scope: rg
  params: {
    name: 'log-${environmentName}'
    location: location
    tags: tags
  }
}

// Removed storage module - PostgreSQL provides all persistence

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.11.3' = {
  name: 'container-apps-env'
  scope: rg
  params: {
    name: 'cae-${environmentName}'
    location: location
    tags: tags
    zoneRedundant: false // Required to be false for Consumption plan without custom VNET
    publicNetworkAccess: 'Enabled'
    infrastructureSubnetResourceId: network.outputs.acaInfrastructureSubnetId
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: monitoring.outputs.logAnalyticsWorkspaceId
        sharedKey: monitoring.outputs.primarySharedKey
      }
    }
  }
}

// PostgreSQL Flexible Server for persistent data storage using AVM
module postgres 'br/public:avm/res/db-for-postgre-sql/flexible-server:0.15.0' = {
  name: 'postgres'
  scope: rg
  params: {
    name: 'pg-owui-${uniqueString(rg.id)}'
    location: location
    tags: tags
    administratorLogin: 'pgadmin'
    administratorLoginPassword: postgresAdminPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    skuName: 'Standard_B1ms'
    tier: 'Burstable'
    storageSizeGB: 32
    version: '16'
    availabilityZone: 1 // Required by AVM module
    highAvailability: 'Disabled' // Explicitly disable HA for Burstable tier
    publicNetworkAccess: 'Disabled'
    delegatedSubnetResourceId: network.outputs.postgresDelegatedSubnetId
    privateDnsZoneArmResourceId: network.outputs.postgresPrivateDnsZoneId
    databases: [
      {
        name: 'openwebui'
      }
    ]
    // Enable diagnostic settings to send logs to Log Analytics
    diagnosticSettings: [
      {
        name: 'sendToLogAnalytics'
        workspaceResourceId: monitoring.outputs.resourceId
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
  }
}


// LiteLLM configuration content
var litellmConfig = '''
model_list:
  # Azure AI Foundry deployed models
  - model_name: gpt-5.4
    litellm_params:
      model: azure/gpt-5.4
      api_base: os.environ/AZURE_API_BASE
      api_version: os.environ/AZURE_API_VERSION

  - model_name: gpt-5.4-mini
    litellm_params:
      model: azure/gpt-5.4-mini
      api_base: os.environ/AZURE_API_BASE
      api_version: os.environ/AZURE_API_VERSION

  # Add more models as needed following the same pattern

litellm_settings:
  drop_params: true
  success_callback: []
  enable_azure_ad_token_refresh: true
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
'''

// LiteLLM Container App (internal ingress only)
module litellm './app/litellm.bicep' = {
  name: 'litellm'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.resourceId
    containerAppName: 'ca-litellm-${environmentName}'
    containerImage: 'ghcr.io/berriai/litellm:main-latest'
    useManagedIdentity: true
    azureApiBase: foundry.outputs.accountEndpoint
    azureApiVersion: '2025-04-01-preview'
    litellmMasterKey: litellmMasterKey
    litellmConfig: litellmConfig
  }
}

module litellmOpenAiUserRole './core/foundry-openai-user-role.bicep' = {
  name: 'litellm-openai-user-role'
  scope: rg
  params: {
    accountName: foundry.outputs.accountName
    principalId: litellm.outputs.principalId
  }
}

// Open WebUI Container App (external ingress with HTTPS)
module openwebui './app/openwebui.bicep' = {
  name: 'openwebui'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.resourceId
    containerAppName: 'ca-openwebui-${environmentName}'
    containerImage: 'ghcr.io/open-webui/open-webui:main'
    litellmUrl: litellm.outputs.litellmInternalUrl
    litellmMasterKey: litellmMasterKey
    postgresServerFqdn: postgres.outputs.fqdn!
    postgresDatabaseName: 'openwebui'
    postgresAdminLogin: 'pgadmin'
    postgresAdminPassword: postgresAdminPassword
    configVersion: deployment().name
  }
}

// Remove the postgresAdmin module - not needed with password auth

// Outputs for azd and user reference
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.outputs.resourceId

output LITELLM_URI string = litellm.outputs.litellmInternalUrl
output LITELLM_NAME string = litellm.outputs.containerAppName

output OPENWEBUI_URI string = openwebui.outputs.openwebuiUrl
output OPENWEBUI_NAME string = openwebui.outputs.containerAppName

output POSTGRES_SERVER string = postgres.outputs.fqdn!
output POSTGRES_DATABASE string = 'openwebui'
output AZURE_AI_ACCOUNT_NAME string = foundry.outputs.accountName
output AZURE_AI_ACCOUNT_ENDPOINT string = foundry.outputs.accountEndpoint
output AZURE_AI_PROJECT_NAME string = foundry.outputs.projectName
output AZURE_AI_PROJECT_ID string = foundry.outputs.projectId
output AZURE_AI_PROJECT_ENDPOINT string = foundry.outputs.projectEndpoint
