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

@description('Location for API Management. Set West US 2 when Basic v2 capacity is unavailable in the primary region.')
param apimLocation string = location

@description('LiteLLM Master Key for API authentication')
@secure()
param litellmMasterKey string

@secure()
param openWebUiSecretKey string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Primary key for LiteLLM to call the APIM Foundry prompt-agent API.')
@secure()
param apimFoundryAgentSubscriptionKey string

@description('Publisher email displayed in API Management')
param apimPublisherEmail string

@description('Container image for LiteLLM. Use a tested explicit version tag.')
param litellmContainerImage string = 'ghcr.io/berriai/litellm:v1.104.0'

@description('Container image for OpenWebUI. Set a tested explicit version tag per deployment.')
param openwebuiContainerImage string

@description('Address space for the POC virtual network.')
param vnetAddressPrefix string = '10.101.0.0/16'

@description('CIDR prefix delegated to the Container Apps environment.')
param containerAppsSubnetPrefix string = '10.101.0.0/23'

@description('CIDR prefix delegated to PostgreSQL Flexible Server.')
param postgresSubnetPrefix string = '10.101.2.0/28'

@description('Create network resources during initial deployment. Set false after delegated subnets are in use.')
param provisionNetwork bool = true

@description('Azure AI Search pricing tier for semantic-hybrid and agentic retrieval.')
@allowed([
  'basic'
  'standard'
])
param searchSkuName string = 'basic'

@description('Foundry prompt agent exposed through the initial APIM Responses facade.')
param promptAgentName string = 'poppy-general-agent'

@description('LiteLLM model alias for the initial Foundry prompt agent.')
param promptAgentModelAlias string = 'poppy-general-agent-responses'

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
    vnetAddressPrefix: vnetAddressPrefix
    containerAppsSubnetPrefix: containerAppsSubnetPrefix
    postgresSubnetPrefix: postgresSubnetPrefix
    provisionNetwork: provisionNetwork
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

module appInsights './core/appinsights.bicep' = {
  name: 'appinsights'
  scope: rg
  params: {
    location: location
    tags: tags
    appInsightsName: 'appi-${environmentName}'
    logAnalyticsWorkspaceId: monitoring.outputs.resourceId
    foundryAccountName: foundry.outputs.accountName
  }
}

module apim './core/apim.bicep' = {
  name: 'apim'
  scope: rg
  params: {
    location: apimLocation
    tags: tags
    apimName: 'apim-${environmentName}'
    publisherName: 'OpenWebUI LiteLLM'
    publisherEmail: apimPublisherEmail
    foundryAccountName: foundry.outputs.accountName
    foundryProjectName: foundry.outputs.projectName
    promptAgentName: promptAgentName
    litellmSubscriptionPrimaryKey: apimFoundryAgentSubscriptionKey
    appInsightsConnectionString: appInsights.outputs.connectionString
  }

}

module directSearchFacade './core/apim-agent-responses-facade.bicep' = {
  name: 'direct-search-facade'
  scope: rg
  params: {
    apimName: apim.outputs.apimName
    foundryAccountName: foundry.outputs.accountName
    foundryProjectName: foundry.outputs.projectName
    agentName: 'poppy-direct-search-agent'
    apiName: 'poppy-direct-search-responses'
    apiPath: 'poppy-direct-search'
    displayName: 'Poppy Direct Azure AI Search Responses'
    productName: 'litellm-foundry-agents'
  }
}

module knowledgeBaseFacade './core/apim-agent-responses-facade.bicep' = {
  name: 'knowledge-base-facade'
  scope: rg
  params: {
    apimName: apim.outputs.apimName
    foundryAccountName: foundry.outputs.accountName
    foundryProjectName: foundry.outputs.projectName
    agentName: 'poppy-knowledge-base-agent'
    apiName: 'poppy-knowledge-base-responses'
    apiPath: 'poppy-knowledge-base'
    displayName: 'Poppy Foundry IQ Knowledge Base Responses'
    productName: 'litellm-foundry-agents'
  }
}

module search './core/search.bicep' = {
  name: 'search'
  scope: rg
  params: {
    location: location
    tags: tags
    searchServiceName: 'srch-${environmentName}-${uniqueString(rg.id)}'
    skuName: searchSkuName
  }
}

module searchRoleAssignments './core/search-role-assignments.bicep' = {
  name: 'search-role-assignments'
  scope: rg
  params: {
    searchServiceName: search.outputs.name
    foundryAccountName: foundry.outputs.accountName
    foundryProjectPrincipalId: foundry.outputs.projectPrincipalId
    foundryAccountPrincipalId: foundry.outputs.accountPrincipalId
    searchServicePrincipalId: search.outputs.principalId
  }
}

module foundrySearchConnection './core/foundry-search-connection.bicep' = {
  name: 'foundry-search-connection'
  scope: rg
  params: {
    foundryAccountName: foundry.outputs.accountName
    foundryProjectName: foundry.outputs.projectName
    searchEndpoint: search.outputs.endpoint
    searchResourceId: search.outputs.resourceId
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

// Private PostgreSQL Flexible Server for persistent application and LiteLLM state.
module postgres './core/postgres-private.bicep' = {
  name: 'postgres'
  scope: rg
  params: {
    location: location
    tags: tags
    serverName: 'pg-owui-${uniqueString(rg.id)}'
    administratorPassword: postgresAdminPassword
    delegatedSubnetResourceId: network.outputs.postgresDelegatedSubnetId
    privateDnsZoneResourceId: network.outputs.postgresPrivateDnsZoneId
    logAnalyticsWorkspaceId: monitoring.outputs.resourceId
  }
}


// Keep model routing in a reviewable LiteLLM config file. Bicep renders the
// environment-specific agent alias without placing secrets in the file.
var litellmConfig = replace(
  loadTextContent('app/litellm-config.yaml'),
  '{{PROMPT_AGENT_MODEL_ALIAS}}',
  promptAgentModelAlias
)

// LiteLLM Container App (internal ingress only)
module litellm './app/litellm.bicep' = {
  name: 'litellm'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.resourceId
    containerAppName: 'ca-litellm-${environmentName}'
    containerImage: litellmContainerImage
    azureApiBase: foundry.outputs.accountEndpoint
    azureApiVersion: '2025-04-01-preview'
    litellmMasterKey: litellmMasterKey
    databaseUrl: 'postgresql://pgadmin:${uriComponent(postgresAdminPassword)}@${postgres.outputs.fqdn!}:5432/litellm?sslmode=require'
    litellmConfig: litellmConfig
    apimFoundryAgentBaseUrl: '${apim.outputs.gatewayUrl}/foundry-prompt-agent'
    apimFoundryAgentSubscriptionKey: apimFoundryAgentSubscriptionKey
    apimDirectSearchBaseUrl: directSearchFacade.outputs.baseUrl
    apimKnowledgeBaseBaseUrl: knowledgeBaseFacade.outputs.baseUrl
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
    containerImage: openwebuiContainerImage
    litellmUrl: litellm.outputs.litellmInternalUrl
    litellmMasterKey: litellmMasterKey
    webuiSecretKey: openWebUiSecretKey
    databaseUrl: 'postgresql://pgadmin:${uriComponent(postgresAdminPassword)}@${postgres.outputs.fqdn!}:5432/openwebui?sslmode=require'
    configVersion: deployment().name
    foundryAgentModelAliases: [
      'gpt-5.4'
      'gpt-5.4-mini'
      promptAgentModelAlias
      'poppy-direct-search-responses'
      'poppy-knowledge-base-responses'
    ]
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
output APIM_NAME string = apim.outputs.apimName
output APIM_GATEWAY_URL string = apim.outputs.gatewayUrl
output APIM_PORTAL_URL string = apim.outputs.portalUrl
output AZURE_SEARCH_NAME string = search.outputs.name
output AZURE_SEARCH_ENDPOINT string = search.outputs.endpoint
