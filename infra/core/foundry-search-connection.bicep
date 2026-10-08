targetScope = 'resourceGroup'

@description('Existing Foundry account name.')
param foundryAccountName string

@description('Existing Foundry project name.')
param foundryProjectName string

@description('Azure AI Search service endpoint.')
param searchEndpoint string

@description('Azure AI Search resource ID.')
param searchResourceId string

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = {
  name: foundryAccountName
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-12-01' existing = {
  parent: foundryAccount
  name: foundryProjectName
}

resource searchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-12-01' = {
  parent: foundryProject
  name: 'poppy-sharepoint-search'
  properties: {
    authType: 'AAD'
    category: 'CognitiveSearch'
    target: searchEndpoint
    isSharedToAll: true
    useWorkspaceManagedIdentity: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchResourceId
    }
  }
}

output connectionId string = searchConnection.id
