// LiteLLM Container App - Internal proxy for Azure AI models

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Resource ID of the Container Apps Environment')
param containerAppsEnvironmentId string

@description('Name of the Container App')
param containerAppName string

@description('Container image to deploy')
param containerImage string

@description('Azure OpenAI / AI Foundry API Base URL')
param azureApiBase string

@description('Azure OpenAI / AI Foundry API Version')
param azureApiVersion string

@description('LiteLLM Master Key for API authentication')
@secure()
param litellmMasterKey string

@description('LiteLLM database connection string')
@secure()
param databaseUrl string

@description('LiteLLM configuration YAML content')
@secure()
param litellmConfig string

@description('APIM base URL for the Foundry prompt-agent Responses facade.')
param apimFoundryAgentBaseUrl string

@description('APIM subscription key used only by LiteLLM for the Foundry prompt-agent API.')
@secure()
param apimFoundryAgentSubscriptionKey string

param apimDirectSearchBaseUrl string

param apimKnowledgeBaseBaseUrl string

// LiteLLM Container App
resource litellmApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 4000
        transport: 'http'
        allowInsecure: false
      }
      secrets: [
          {
            name: 'litellm-master-key'
            value: litellmMasterKey
          }
          {
            name: 'litellm-config'
            value: litellmConfig
          }
          {
            name: 'database-url'
            value: databaseUrl
          }
          {
            name: 'apim-foundry-agent-subscription-key'
            value: apimFoundryAgentSubscriptionKey
          }
        ]
    }
    template: {
      containers: [
        {
          name: 'litellm'
          image: containerImage
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
              {
                name: 'AZURE_API_BASE'
                value: azureApiBase
              }
              {
                name: 'AZURE_API_VERSION'
                value: azureApiVersion
              }
              {
                name: 'LITELLM_MASTER_KEY'
                secretRef: 'litellm-master-key'
              }
              {
                name: 'LITELLM_CONFIG'
                secretRef: 'litellm-config'
              }
              {
                name: 'DATABASE_URL'
                secretRef: 'database-url'
              }
              {
                name: 'APIM_FOUNDRY_AGENT_BASE_URL'
                value: apimFoundryAgentBaseUrl
              }
              {
                name: 'APIM_FOUNDRY_AGENT_SUBSCRIPTION_KEY'
                secretRef: 'apim-foundry-agent-subscription-key'
              }
              {
                name: 'APIM_DIRECT_SEARCH_BASE_URL'
                value: apimDirectSearchBaseUrl
              }
              {
                name: 'APIM_KNOWLEDGE_BASE_BASE_URL'
                value: apimKnowledgeBaseBaseUrl
              }
            ]
          command: [
            '/bin/sh'
            '-c'
            'echo "$LITELLM_CONFIG" > /app/config.yaml && litellm --config /app/config.yaml --detailed_debug'
          ]
        }
      ]
      scale: {
        cooldownPeriod: 1800
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppId string = litellmApp.id
output containerAppName string = litellmApp.name
output litellmInternalUrl string = 'http://${litellmApp.name}/v1'
output litellmFqdn string = litellmApp.properties.configuration.ingress.fqdn
output principalId string = litellmApp.identity.principalId
