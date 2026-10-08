targetScope = 'resourceGroup'

@description('Location for network resources.')
param location string

@description('Tags to apply to network resources.')
param tags object = {}

@description('Name of the virtual network.')
param vnetName string

@description('Address space for the virtual network.')
param vnetAddressPrefix string = '10.101.0.0/16'

@description('CIDR prefix delegated to the Container Apps environment.')
param containerAppsSubnetPrefix string = '10.101.0.0/23'

@description('CIDR prefix delegated to PostgreSQL Flexible Server.')
param postgresSubnetPrefix string = '10.101.2.0/28'

@description('Create the VNet, delegated subnets, private DNS zone, and link. Set false after initial deployment to avoid updates to in-use delegated subnets.')
param provisionNetwork bool = true

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (provisionNetwork) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'aca-infrastructure'
        properties: {
          addressPrefix: containerAppsSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          delegations: [
            {
              name: 'container-apps-environment'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'postgres'
        properties: {
          addressPrefix: postgresSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          delegations: [
            {
              name: 'postgres-flexible-server'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (provisionNetwork) {
  name: 'private.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource postgresDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (provisionNetwork) {
  parent: postgresPrivateDnsZone
  name: '${vnet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output acaInfrastructureSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  'aca-infrastructure'
)
output postgresDelegatedSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  'postgres'
)
output postgresPrivateDnsZoneId string = resourceId(
  'Microsoft.Network/privateDnsZones',
  'private.postgres.database.azure.com'
)
