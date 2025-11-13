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

@description('Use Managed Identity for Azure authentication instead of API key')
param useManagedIdentity bool = false

@description('Azure OpenAI / AI Foundry API Key (only required if useManagedIdentity is false)')
@secure()
param azureApiKey string = ''

@description('Azure OpenAI / AI Foundry API Base URL')
param azureApiBase string

@description('Azure OpenAI / AI Foundry API Version')
param azureApiVersion string = '2024-08-01-preview'

@description('LiteLLM Master Key for API authentication')
@secure()
param litellmMasterKey string

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

// Core infrastructure: Log Analytics, Container Apps Environment, Storage
module monitoring './core/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: 'log-${environmentName}'
  }
}

// Removed storage module - PostgreSQL provides all persistence

module containerAppsEnvironment './core/container-apps-env.bicep' = {
  name: 'container-apps-env'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentName: 'cae-${environmentName}'
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// PostgreSQL Flexible Server for persistent data storage
var postgresPassword = uniqueString(rg.id, 'postgres', environmentName)

module postgres './core/postgres.bicep' = {
  name: 'postgres'
  scope: rg
  params: {
    location: 'centralus' // PostgreSQL not available in eastus2, deploy to Central US
    tags: tags
    name: 'pg-owui-${uniqueString(rg.id)}' // Globally unique name
    databaseName: 'openwebui'
    administratorLogin: 'pgadmin'
    administratorLoginPassword: postgresPassword
    allowAzureIPsFirewall: true
  }
}

// LiteLLM configuration content
var litellmConfig = '''
model_list:
  # Azure AI Foundry deployed models
  - model_name: gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: os.environ/AZURE_API_VERSION

  - model_name: gpt-4o-mini
    litellm_params:
      model: azure/gpt-4o-mini
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: os.environ/AZURE_API_VERSION

  # Add more models as needed following the same pattern

litellm_settings:
  drop_params: true
  success_callback: []
  enable_azure_ad_token_refresh: true  # Enable fallback to managed identity when API key is not provided

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
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.containerAppsEnvironmentId
    containerAppName: 'ca-litellm-${environmentName}'
    containerImage: 'ghcr.io/berriai/litellm:main-latest'
    useManagedIdentity: useManagedIdentity
    azureApiKey: azureApiKey
    azureApiBase: azureApiBase
    azureApiVersion: azureApiVersion
    litellmMasterKey: litellmMasterKey
    litellmConfig: litellmConfig
  }
}

// Open WebUI Container App (external ingress with HTTPS)
module openwebui './app/openwebui.bicep' = {
  name: 'openwebui'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.containerAppsEnvironmentId
    containerAppName: 'ca-openwebui-${environmentName}'
    containerImage: 'ghcr.io/open-webui/open-webui:main'
    litellmUrl: litellm.outputs.litellmInternalUrl
    litellmMasterKey: litellmMasterKey
    postgresServerFqdn: postgres.outputs.postgresServerFqdn
    postgresDatabaseName: postgres.outputs.databaseName
    postgresAdminLogin: 'pgadmin'
    postgresAdminPassword: postgresPassword
  }
}

// Remove the postgresAdmin module - not needed with password auth

// Outputs for azd and user reference
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.outputs.containerAppsEnvironmentId

output LITELLM_URI string = litellm.outputs.litellmInternalUrl
output LITELLM_NAME string = litellm.outputs.containerAppName

output OPENWEBUI_URI string = openwebui.outputs.openwebuiUrl
output OPENWEBUI_NAME string = openwebui.outputs.containerAppName

output POSTGRES_SERVER string = postgres.outputs.postgresServerFqdn
output POSTGRES_DATABASE string = postgres.outputs.databaseName
