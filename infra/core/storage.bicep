// Azure Storage Account with File Share for Open WebUI data persistence

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Name of the Storage Account (3-24 chars, lowercase alphanumeric)')
@minLength(3)
@maxLength(24)
param storageAccountName string

// Storage Account for persistent data
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS' // Locally redundant storage for cost optimization
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // Required for Azure Files with Container Apps
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny' // Deny public access
      bypass: 'AzureServices' // Allow Azure services (Container Apps) to access
    }
  }
}

// File Services for SMB file shares
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// File Share for Open WebUI data
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileServices
  name: 'openwebui-data'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 10 // 10 GB quota
    enabledProtocols: 'SMB'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
