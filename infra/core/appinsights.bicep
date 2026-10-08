targetScope = 'resourceGroup'

@description('Location for Application Insights.')
param location string

@description('Tags to apply to Application Insights.')
param tags object = {}

@description('Name of the Application Insights component.')
param appInsightsName string

@description('Existing Log Analytics workspace resource ID.')
param logAnalyticsWorkspaceId string

@description('Existing Foundry account name.')
param foundryAccountName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = {
  name: foundryAccountName
}

resource foundryAppInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-12-01' = {
  parent: foundryAccount
  name: 'appinsights'
  properties: {
    authType: 'ApiKey'
    category: 'AppInsights'
    target: appInsights.id
    isSharedToAll: true
    useWorkspaceManagedIdentity: false
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
    credentials: {
      key: appInsights.properties.ConnectionString
    }
  }
}

output appInsightsId string = appInsights.id
output connectionString string = appInsights.properties.ConnectionString
