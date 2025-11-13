// Container Apps Environment for hosting containerized applications

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Name of the Container Apps Environment')
param containerAppsEnvironmentName string

@description('Resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

// Get the Log Analytics workspace to retrieve keys
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: split(logAnalyticsWorkspaceId, '/')[8]
}

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false // Set to true for production high availability
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerAppsEnvironmentDefaultDomain string = containerAppsEnvironment.properties.defaultDomain
