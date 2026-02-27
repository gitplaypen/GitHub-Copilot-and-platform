targetScope = 'resourceGroup'

@description('Environment name (e.g. dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = 'westus3'

@description('Base name prefix for all resources')
param resourcePrefix string = 'zavastore'

@description('Container image to deploy (defaults to a placeholder; update after first ACR push)')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ──────────────────────────────────────────────────────
// Derived resource names (consistent naming scheme)
// ──────────────────────────────────────────────────────
var acrName = replace('${resourcePrefix}acr${environmentName}', '-', '')
var appPlanName = 'asp-${resourcePrefix}-${environmentName}'
var appName = 'app-${resourcePrefix}-${environmentName}'
var appInsightsName = 'ai-${resourcePrefix}-${environmentName}'
var logAnalyticsName = 'log-${resourcePrefix}-${environmentName}'
var aiFoundryName = 'aif-${resourcePrefix}-${environmentName}'

var tags = {
  environment: environmentName
  project: 'ZavaStorefront'
  managedBy: 'AZD'
}

// ──────────────────────────────────────────────────────
// Log Analytics Workspace
// ──────────────────────────────────────────────────────
module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

// ──────────────────────────────────────────────────────
// Azure Container Registry
// ──────────────────────────────────────────────────────
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    name: acrName
    location: location
    sku: 'Basic'
    tags: tags
  }
}

// ──────────────────────────────────────────────────────
// Application Insights
// ──────────────────────────────────────────────────────
module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights'
  params: {
    name: appInsightsName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    tags: tags
  }
}

// ──────────────────────────────────────────────────────
// App Service Plan + Web App (Linux container)
// ──────────────────────────────────────────────────────
module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    planName: appPlanName
    appName: appName
    location: location
    acrLoginServer: acr.outputs.loginServer
    containerImage: containerImage
    appInsightsConnectionString: appInsights.outputs.connectionString
    skuName: 'B1'
    tags: tags
  }
}

// ──────────────────────────────────────────────────────
// AcrPull role assignment: App Service managed identity → ACR
// Built-in AcrPull role ID: 7f951dda-4ed3-4680-a7ca-43fe172d538d
// Scoped to the ACR resource only (principle of least privilege)
// ──────────────────────────────────────────────────────
resource existingAcr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acr.outputs.name
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.outputs.id, appService.outputs.principalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: existingAcr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: appService.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ──────────────────────────────────────────────────────
// Azure AI Foundry (GPT-4 and Phi model access in westus3)
// ──────────────────────────────────────────────────────
module aiFoundry 'modules/aiFoundry.bicep' = {
  name: 'aiFoundry'
  params: {
    name: aiFoundryName
    location: location
    tags: tags
  }
}

// ──────────────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────────────
output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.name
output appServiceName string = appService.outputs.name
output appServiceUrl string = 'https://${appService.outputs.defaultHostName}'
output appInsightsConnectionString string = appInsights.outputs.connectionString
output aiFoundryName string = aiFoundry.outputs.name
