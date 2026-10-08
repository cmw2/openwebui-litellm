targetScope = 'resourceGroup'

@description('Existing Azure AI Search service name.')
param searchServiceName string

@description('Existing Foundry account name.')
param foundryAccountName string

@description('Foundry project managed identity principal ID.')
param foundryProjectPrincipalId string

@description('Foundry account managed identity principal ID.')
param foundryAccountPrincipalId string

@description('Azure AI Search system-assigned managed identity principal ID.')
param searchServicePrincipalId string

resource searchService 'Microsoft.Search/searchServices@2025-05-01' existing = {
  name: searchServiceName
}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = {
  name: foundryAccountName
}

resource searchIndexDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, foundryProjectPrincipalId, 'Search Index Data Reader')
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    )
  }
}

resource searchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, foundryAccountPrincipalId, 'Search Index Data Contributor')
  properties: {
    principalId: foundryAccountPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    )
  }
}

resource projectSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, foundryProjectPrincipalId, 'Search Index Data Contributor')
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    )
  }
}

resource searchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, foundryAccountPrincipalId, 'Search Service Contributor')
  properties: {
    principalId: foundryAccountPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    )
  }
}

resource projectSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, foundryProjectPrincipalId, 'Search Service Contributor')
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    )
  }
}

resource cognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundryAccount
  name: guid(foundryAccount.id, searchServicePrincipalId, 'Cognitive Services User')
  properties: {
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a97b65f3-24c7-4388-baec-2e87135dc908'
    )
  }
}
