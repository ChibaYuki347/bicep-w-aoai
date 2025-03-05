@description('Application Name')
@maxLength(30)
param applicationName string = 'to-do-app${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
])
@description('App Service Plan\'s pricing tier. Details at https://azure.microsoft.com/pricing/details/app-service/')
param appServicePlanTier string = 'F1'

@minValue(1)
@maxValue(3)
@description('App Service Plan\'s instance count')
param appServicePlanInstances int = 1

@description('The URL for the GitHub repository that contains the project to deploy.')
param repositoryUrl string = 'https://github.com/Azure-Samples/cosmos-dotnet-core-todo-app.git'

@description('The branch of the GitHub repository to use.')
param branch string = 'main'

@description('The Cosmos DB database name.')
param databaseName string = 'Tasks'

@description('The Cosmos DB container name.')
param containerName string = 'Items'

@description('The name of the virtual network.')
param vnetName string

// Azure OpenAI
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

//Private endpoint
// use private endpoint
@description('Use private endpoints for the resources')
param usePrivateEndpoint bool = false

// public network access
@description('Public network access value for all deployed resources')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// resource token for the private endpoint
@description('Resource token for the private endpoint')
param resourceToken string

// use application insights
@description('Use application insights for the resources')
param useApplicationInsights bool = false

// application insights name
@description('Application Insights name')
param applicationInsightsName string = ''

// log analytics name
@description('Log Analytics name')
param logAnalyticsName string = ''




var abbrs = loadJsonContent('./abbreviations.json')
var cosmosAccountName = toLower(applicationName)
var websiteName = applicationName
var hostingPlanName = applicationName

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: cosmosAccountName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: publicNetworkAccess
    // virtualNetworkRules: [
    //   {
    //     id: isolation.outputs.cosmosSubnetId
    //     ignoreMissingVNetServiceEndpoint: false
    //   }
    // ]
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: appServicePlanTier
    capacity: appServicePlanInstances
  }
}

resource website 'Microsoft.Web/sites@2021-03-01' = {
  name: websiteName
  location: location
  properties: {
    serverFarmId: hostingPlan.id
    virtualNetworkSubnetId: isolation.outputs.appSubnetId
    siteConfig: {
      appSettings: [
        {
          name: 'CosmosDb:Account'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'CosmosDb:Key'
          value: cosmosAccount.listKeys().primaryMasterKey
        }
        {
          name: 'CosmosDb:DatabaseName'
          value: databaseName
        }
        {
          name: 'CosmosDb:ContainerName'
          value: containerName
        }
      ]
    }
  }
}

resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-03-01' = {
  name: 'web'
  parent: website
  properties: {
    repoUrl: repositoryUrl
    branch: branch
    isManualIntegration: true
  }
}

// Azure OpenAI
module openai 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  params: {
    name: 'aoai${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openaiRegion
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
    publicNetworkAccess: publicNetworkAccess
  }
}

module isolation 'network-isolation.bicep' = if (usePrivateEndpoint) {
  name: 'isolation'
  params: {
    location: location
    vnetName: vnetName
    appServicePlanName: hostingPlanName
    usePrivateEndpoint: true
  }
}

var openaiProvateEndppointConnection = [{
  groupId: 'account'
  dnsZoneName: 'privatelink.openai.com'
  resourceIds: [openai.outputs.id]
}]

var cosmosPrivateEndpointConnection = [{
  groupId: 'sql'
  dnsZoneName: 'privatelink.documents.azure.com'
  resourceIds: [cosmosAccount.id]
}]

var privateEndpointConnections = concat(openaiProvateEndppointConnection, cosmosPrivateEndpointConnection)

// TODO:Monitor application with Azure Monitor
// module monitoring 'core/monitor/monitoring.bicep' = if (useApplicationInsights) {
//   name: 'monitoring'
//   params: {
//     location: location
//     applicationInsightsName: !empty(applicationInsightsName)
//       ? applicationInsightsName
//       : '${abbrs.insightsComponents}${resourceToken}'
//     logAnalyticsName: !empty(logAnalyticsName)
//       ? logAnalyticsName!Yfa17935
//       : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
//     publicNetworkAccess: publicNetworkAccess
//   }
// }

module privateEndpoints 'private-endpoints.bicep' = if (usePrivateEndpoint) {
  name: 'privateEndpoints'
  params: {
    location: location
    resourceToken: resourceToken
    privateEndpointConnections: privateEndpointConnections
    vnetName: isolation.outputs.vnetName
    vnetPeSubnetName: isolation.outputs.backendSubnetId
  }
}

output AZURE_OPENAI_ENDPOINT string = openai.outputs.endpoint
output AZURE_OPENAI_API_KEY string = openai.outputs.accountKey
