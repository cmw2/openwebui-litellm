targetScope = 'resourceGroup'

@description('Location for Foundry resources.')
param location string

@description('Tags to apply to Foundry resources.')
param tags object = {}

@description('Name of the Azure AI Services Foundry account.')
param accountName string

@description('Name of the Foundry project.')
param projectName string

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-12-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-12-01' = {
  parent: aiServices
  name: projectName
  location: location
  tags: tags
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource gpt54Deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  parent: aiServices
  name: 'gpt-5.4'
  dependsOn: [
    aiProject
  ]
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.4'
      version: '2026-03-05'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

resource gpt54MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  parent: aiServices
  name: 'gpt-5.4-mini'
  dependsOn: [
    gpt54Deployment
  ]
  sku: {
    name: 'GlobalStandard'
    capacity: 20
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.4-mini'
      version: '2026-03-17'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

output accountId string = aiServices.id
output accountName string = aiServices.name
output accountEndpoint string = aiServices.properties.endpoint
output projectId string = aiProject.id
output projectName string = aiProject.name
output projectEndpoint string = 'https://${accountName}.services.ai.azure.com/api/projects/${projectName}'
