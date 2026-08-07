targetScope = 'resourceGroup'

@description('Name of the Azure AI Services Foundry account.')
param accountName string

@description('Object ID of the managed identity that calls the model deployments.')
param principalId string

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = {
  name: accountName
}

resource openAiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiServices
  name: guid(aiServices.id, principalId, 'Cognitive Services OpenAI User')
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    )
  }
}
