@description('The tags to apply to all resources')
param tags object = {}

@description('The name of an existing VNet')
param vnetName string

@description('The location to create the private endpoints')
param location string = resourceGroup().location

param vnetPeSubnetName string

@description('A formatted array of private endpoint connections containing the dns zone name, group id, and list of resource ids of Private Endpoints to create')
param privateEndpointConnections array

@description('A unique token to append to the end of all resource names')
param resourceToken string

var abbrs = loadJsonContent('abbreviations.json')

// DNS Zones
module dnsZones './core/networking/private-dns-zones.bicep' = [for privateEndpointConnection in privateEndpointConnections: {
  name: '${privateEndpointConnection.groupId}-dnszone'
  params: {
    dnsZoneName: privateEndpointConnection.dnsZoneName
    tags: tags
    virtualNetworkName: vnetName
  }
}]

// Private Endpoints
var privateEndpointInfo = [
  for (privateEndpointConnection, i) in privateEndpointConnections: map(privateEndpointConnection.resourceIds, resourceId => {
    dnsZoneIndex: i
    groupId: privateEndpointConnection.groupId
    name: last(split(resourceId, '/'))
    resourceId: resourceId
  })
]
module privateEndpoints './core/networking/private-endpoint.bicep' = [for privateEndpointInfo in flatten(privateEndpointInfo): {
  name: '${privateEndpointInfo.name}-privateendpoint'
  params: {
    location: location
    name: '${privateEndpointInfo.name}${abbrs.privateEndpoint}${resourceToken}'
    tags: tags
    subnetId: vnetPeSubnetName
    serviceId: privateEndpointInfo.resourceId
    groupIds: [ privateEndpointInfo.groupId ]
    dnsZoneId: dnsZones[privateEndpointInfo.dnsZoneIndex].outputs.id
  }
  dependsOn: [ dnsZones ]
}]

output privateEndpointIds array = [for (privateEndpointInfo,i) in flatten(privateEndpointInfo): {
  id: privateEndpoints[i].outputs.id
  name: privateEndpoints[i].outputs.name
}]
