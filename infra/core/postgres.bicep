param name string
param location string = resourceGroup().location
param tags object = {}

param administratorLogin string = 'pgadmin'
@secure()
param administratorLoginPassword string
param allowAzureIPsFirewall bool = true
param databaseName string = 'openwebui'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    storage: {
      storageSizeGB: 32
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgresServer
  name: databaseName
}

// Allow Azure services to access the server
resource allowAzureIPs 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = if (allowAzureIPsFirewall) {
  name: 'allow-azure-services'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
output postgresServerId string = postgresServer.id
