targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// openai resouce region
@description('Region for the OpenAI resource')
@allowed(['eastus2', 'westus'])
param openaiRegion string = 'westus'

// deployment name of the openai resource
@description('Deployment name of the OpenAI resource')
param deploymentName string = 'gpt-4o'

// deployment version of the openai resource
@description('Deployment version of the OpenAI resource')
param deploymentVersion string = '2024-05-13'

var abbrs = loadJsonContent('./abbreviations.json')

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

// Cosmos DB + App Service
module resources './resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
  }
}

// Azure OpenAI
module openai 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: rg
  params: {
    name: 'aoai${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openaiRegion
    tags: tags
    sku: {
      name: 'S0'
    }
    deployments: [
      {
        name: 'gpt-4o'
        model: {
          format: 'OpenAI'
          name: deploymentName
          version: deploymentVersion
        }
        sku: {
          name: 'Standard'
          capacity: 100
        }
      }
    ]
  }
}


output AZURE_OPENAI_ENDPOINT string = openai.outputs.endpoint
output AZURE_OPENAI_API_KEY string = openai.outputs.accountKey
output DEPLOYMENT_NAME string = deploymentName
output API_VERSION string = '2024-05-01-preview'
