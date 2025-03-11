@description('Location for all resources.')
param location string = resourceGroup().location

@description('The URL for the GitHub repository that contains the project to deploy.')
param repositoryUrl string = 'https://github.com/Azure-Samples/cosmos-dotnet-core-todo-app.git'

@description('The branch of the GitHub repository to use.')
param branch string = 'main'

@description('The Cosmos DB database name.')
param databaseName string = 'Tasks'

@description('The Cosmos DB container name.')
param containerName string = 'Items'

@description('Resource token for the private endpoint')
param resourceToken string

@description('Web App Name')
param webAppName string = 'todo-app-${resourceToken}'

@description('Existing Cosmos DB account name')
param cosmosAccountName string

@description('Existing Hosting Plan Name')
param hostingPlanName string

@description('Existing Virtual Network Subnet ID')
param virtualNetworkSubnetId string

//monitoring
@description('Existing Application Insights Name')
param applicationInsightsName string = ''

@description('Existing Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string = ''

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: cosmosAccountName
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: hostingPlanName
}

var appSettings = {
  'CosmosDb:Account': cosmosAccount.properties.documentEndpoint
  'CosmosDb:Key': cosmosAccount.listKeys().primaryMasterKey
  'CosmosDb:DatabaseName': databaseName
  'CosmosDb:ContainerName': containerName
}

resource website 'Microsoft.Web/sites@2021-03-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: hostingPlan.id
    virtualNetworkSubnetId: !empty(virtualNetworkSubnetId) ? virtualNetworkSubnetId : null
    }
  }

resource settings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'appsettings'
  parent: website
    properties: union(
      appSettings,
      !empty(applicationInsightsName) ? { APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString } : {}
    )
  }

  resource website_diagnosticsettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
    name: '${website.name}-diagnostic-settings'
    scope: website
    properties: {
      workspaceId: logAnalyticsWorkspaceId
      logs: [
        {
          categoryGroup: 'allLogs'
          enabled: true
        }
      ]
      metrics: [
        {
          category: 'AllMetrics'
          enabled: true
        }
      ]
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

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}
