targetScope = 'resourceGroup'

@description('Location for Azure AI Search.')
param location string

@description('Tags to apply to Azure AI Search.')
param tags object = {}

@description('Azure AI Search service name.')
param searchServiceName string

@description('Search pricing tier. Basic is the minimum tier for the SharePoint indexer.')
@allowed([
  'basic'
  'standard'
])
param skuName string = 'basic'

resource searchService 'Microsoft.Search/searchServices@2025-05-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    disableLocalAuth: false
    hostingMode: 'Default'
    partitionCount: 1
    publicNetworkAccess: 'Enabled'
    replicaCount: 1
    semanticSearch: 'standard'
  }
}

output id string = searchService.id
output name string = searchService.name
output endpoint string = 'https://${searchService.name}.search.windows.net'
output resourceId string = searchService.id
output principalId string = searchService.identity.principalId
