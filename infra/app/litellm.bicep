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

@description('Use Managed Identity for Azure authentication instead of API key')
param useManagedIdentity bool = false

@description('Azure OpenAI / AI Foundry API Key (only required if useManagedIdentity is false)')
@secure()
param azureApiKey string = ''

@description('Azure OpenAI / AI Foundry API Base URL')
param azureApiBase string

@description('Azure OpenAI / AI Foundry API Version')
param azureApiVersion string

@description('LiteLLM Master Key for API authentication')
@secure()
param litellmMasterKey string

@description('LiteLLM configuration YAML content')
@secure()
param litellmConfig string

// LiteLLM Container App
resource litellmApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: useManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    environmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: false // Internal only - not exposed to internet
        targetPort: 4000
        transport: 'http'
        allowInsecure: false
      }
      secrets: concat(
        [
          {
            name: 'litellm-master-key'
            value: litellmMasterKey
          }
          {
            name: 'litellm-config'
            value: litellmConfig
          }
        ],
        // Only add azure-api-key secret if not using managed identity
        !useManagedIdentity && !empty(azureApiKey) ? [
          {
            name: 'azure-api-key'
            value: azureApiKey
          }
        ] : []
      )
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
          env: concat(
            [
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
            ],
            // Only add AZURE_API_KEY env var if not using managed identity
            !useManagedIdentity && !empty(azureApiKey) ? [
              {
                name: 'AZURE_API_KEY'
                secretRef: 'azure-api-key'
              }
            ] : []
          )
          command: [
            '/bin/sh'
            '-c'
            'echo "$LITELLM_CONFIG" > /app/config.yaml && litellm --config /app/config.yaml --detailed_debug'
          ]
        }
      ]
      scale: {
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
