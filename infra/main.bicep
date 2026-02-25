// ============================================================================
// ZavaStorefront Infrastructure - Main Bicep Template
// Environment: Development (dev)
// Region: westus3
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Azure environment (used for resource naming)')
param environmentName string

@description('Primary location for all resources')
param location string

@description('Name of the resource group')
param resourceGroupName string = 'rg-${environmentName}'

// ============================================================================
// Variables
// ============================================================================

// Resource token for unique naming (subscription scope)
var resourceToken = uniqueString(subscription().id, location, environmentName)

// Resource naming - format: az{prefix}{token}, max 32 chars, alphanumeric only
var names = {
  resourceGroup: resourceGroupName
  managedIdentity: 'azid${resourceToken}'
  containerRegistry: 'azacr${resourceToken}'
  logAnalytics: 'azlog${resourceToken}'
  appInsights: 'azappi${resourceToken}'
  appServicePlan: 'azasp${resourceToken}'
  appService: 'azapp${resourceToken}'
  aiFoundry: 'azai${resourceToken}'
}

// Tags
var tags = {
  'azd-env-name': environmentName
  environment: 'dev'
  application: 'zavastorefront'
}

// ============================================================================
// Resource Group
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: names.resourceGroup
  location: location
  tags: tags
}

// ============================================================================
// Modules
// ============================================================================

// User Assigned Managed Identity
module identity 'modules/identity.bicep' = {
  name: 'identity-deployment'
  scope: rg
  params: {
    name: names.managedIdentity
    location: location
    tags: tags
  }
}

// Azure Container Registry
module containerRegistry 'modules/containerRegistry.bicep' = {
  name: 'acr-deployment'
  scope: rg
  params: {
    name: names.containerRegistry
    location: location
    tags: tags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// Log Analytics Workspace
module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'log-analytics-deployment'
  scope: rg
  params: {
    name: names.logAnalytics
    location: location
    tags: tags
  }
}

// Application Insights
module appInsights 'modules/appInsights.bicep' = {
  name: 'app-insights-deployment'
  scope: rg
  params: {
    name: names.appInsights
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// App Service (Linux with Docker container support)
module appService 'modules/appService.bicep' = {
  name: 'app-service-deployment'
  scope: rg
  params: {
    appServicePlanName: names.appServicePlan
    appServiceName: names.appService
    location: location
    tags: tags
    managedIdentityId: identity.outputs.id
    managedIdentityClientId: identity.outputs.clientId
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
  }
}

// Azure AI Foundry (Cognitive Services)
module aiFoundry 'modules/aiFoundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    name: names.aiFoundry
    location: location
    tags: tags
    managedIdentityPrincipalId: identity.outputs.principalId
  }
}

// ============================================================================
// Outputs
// ============================================================================

// Required by AZD
output RESOURCE_GROUP_ID string = rg.id

// Resource information
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_LOGIN_SERVER string = containerRegistry.outputs.loginServer
output AZURE_APP_SERVICE_NAME string = appService.outputs.name
output AZURE_APP_SERVICE_URL string = appService.outputs.url
output AZURE_APP_INSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
output AZURE_AI_FOUNDRY_ENDPOINT string = aiFoundry.outputs.endpoint
output AZURE_MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.clientId
