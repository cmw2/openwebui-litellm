// Configure PostgreSQL administrator using Entra ID (Azure AD)
param postgresServerName string
param administratorPrincipalId string
param administratorPrincipalName string = 'Open WebUI Container App'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' existing = {
  name: postgresServerName
}

resource postgresAdministrator 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2023-03-01-preview' = {
  name: administratorPrincipalId
  parent: postgresServer
  properties: {
    principalName: administratorPrincipalName
    principalType: 'ServicePrincipal'
    tenantId: tenant().tenantId
  }
}

output administratorId string = postgresAdministrator.id
