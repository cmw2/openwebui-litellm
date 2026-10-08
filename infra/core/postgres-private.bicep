targetScope = 'resourceGroup'

@description('Location for PostgreSQL.')
param location string

@description('Tags to apply to PostgreSQL.')
param tags object = {}

@description('PostgreSQL Flexible Server name.')
param serverName string

@description('Administrator login name.')
param administratorLogin string = 'pgadmin'

@secure()
@description('Administrator password.')
param administratorPassword string

@description('Delegated subnet resource ID for private access.')
param delegatedSubnetResourceId string

@description('Private DNS zone resource ID for PostgreSQL.')
param privateDnsZoneResourceId string

@description('Log Analytics workspace resource ID.')
param logAnalyticsWorkspaceId string

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    availabilityZone: '1'
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: delegatedSubnetResourceId
      privateDnsZoneArmResourceId: privateDnsZoneResourceId
    }
    storage: {
      autoGrow: 'Enabled'
      storageSizeGB: 32
    }
    version: '16'
  }
}

resource openwebuiDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: 'openwebui'
}

resource litellmDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: 'litellm'
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: postgresServer
  name: 'sendToLogAnalytics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output fqdn string = postgresServer.properties.fullyQualifiedDomainName
output id string = postgresServer.id
