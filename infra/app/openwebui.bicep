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

@description('PostgreSQL Server FQDN')
param postgresServerFqdn string

@description('PostgreSQL Database Name')
param postgresDatabaseName string

@description('PostgreSQL Administrator Login')
param postgresAdminLogin string

@description('PostgreSQL Administrator Password')
@secure()
param postgresAdminPassword string

@description('Changes on each infrastructure deployment to refresh secret references.')
param configVersion string

// Open WebUI Container App (create with managed identity)
resource openwebuiApp 'Microsoft.App/containerApps@2024-03-01' = {
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
          name: 'postgres-password'
          value: postgresAdminPassword
        }
        {
          name: 'database-url'
          value: 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgresServerFqdn}:5432/${postgresDatabaseName}?sslmode=require'
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
