// Open WebUI Container App - Web interface with external HTTPS ingress

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

@description('Internal URL of the LiteLLM service')
param litellmUrl string

@description('LiteLLM Master Key for API authentication')
@secure()
param litellmMasterKey string

@secure()
param webuiSecretKey string

@description('OpenWebUI PostgreSQL connection string.')
@secure()
param databaseUrl string

@description('Changes on each infrastructure deployment to refresh secret references.')
param configVersion string

@description('LiteLLM alias for the Foundry Responses agent.')
param foundryAgentModelAliases array

// Open WebUI Container App (create with managed identity)
resource openwebuiApp 'Microsoft.App/containerApps@2025-01-01' = {
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
        external: true // External HTTPS ingress
        targetPort: 8080
        transport: 'auto' // Enables HTTPS
        allowInsecure: false
      }
      secrets: [
        {
          name: 'litellm-master-key'
          value: litellmMasterKey
        }
        {
          name: 'webui-secret-key'
          value: webuiSecretKey
        }
        {
          name: 'database-url'
          value: databaseUrl
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'openwebui'
          image: containerImage
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'OPENAI_API_BASE_URL'
              value: litellmUrl
            }
            {
              name: 'OPENAI_API_KEY'
              secretRef: 'litellm-master-key'
            }
            {
              name: 'WEBUI_SECRET_KEY'
              secretRef: 'webui-secret-key'
            }
            {
              name: 'OPENAI_API_BASE_URLS'
              value: litellmUrl
            }
            {
              name: 'OPENAI_API_KEYS'
              secretRef: 'litellm-master-key'
            }
            {
              name: 'OPENAI_API_CONFIGS'
              value: '{"0":{"api_type":"responses","model_ids":${string(foundryAgentModelAliases)}}}'
            }
            {
              name: 'ENABLE_PERSISTENT_CONFIG'
              value: 'false'
            }
            {
              name: 'DATABASE_URL'
              secretRef: 'database-url'
            }
            {
              name: 'CONFIG_VERSION'
              value: configVersion
            }
          ]
        }
      ]
      scale: {
        cooldownPeriod: 1800
        minReplicas: 0
        maxReplicas: 5
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppId string = openwebuiApp.id
output principalId string = openwebuiApp.identity.principalId
output containerAppName string = openwebuiApp.name
output openwebuiUrl string = 'https://${openwebuiApp.properties.configuration.ingress.fqdn}'
output openwebuiFqdn string = openwebuiApp.properties.configuration.ingress.fqdn
