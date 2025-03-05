targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Use Private Endpoint')
param usePrivateEndpoint bool = false

// public network access
@description('Public network access value for all deployed resources')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Generate a unique token to be used in naming resources.
// Remove linter suppression after using.
#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Cosmos DB + App Service + Azure OpenAI
module resources './resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    vnetName: 'vnet-${environmentName}'
    appServicePlanTier: 'B1'
    resourceToken: resourceToken
    usePrivateEndpoint: usePrivateEndpoint
    publicNetworkAccess:  publicNetworkAccess
  }
}


output AZURE_OPENAI_ENDPOINT string = resources.outputs.AZURE_OPENAI_ENDPOINT
output AZURE_OPENAI_API_KEY string = resources.outputs.AZURE_OPENAI_API_KEY
