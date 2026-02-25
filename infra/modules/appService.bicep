// ============================================================================
// App Service Module (Linux with Docker Container)
// ============================================================================

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Name of the App Service')
param appServiceName string

@description('Location for the resource')
param location string

@description('Tags to apply to resources')
param tags object

@description('User Assigned Managed Identity resource ID')
param managedIdentityId string

@description('User Assigned Managed Identity client ID')
param managedIdentityClientId string

@description('Container Registry login server')
param containerRegistryLoginServer string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

// ============================================================================
// Variables
// ============================================================================

// Default placeholder image until real image is pushed
var defaultDockerImage = 'mcr.microsoft.com/dotnet/samples:aspnetapp'

// AZD service tag (must match service name in azure.yaml)
var azdServiceTags = {
  'azd-service-name': 'web'
}

// ============================================================================
// Resources
// ============================================================================

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// App Service (Linux Container)
resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  tags: union(tags, azdServiceTags)
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${defaultDockerImage}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentityClientId
      alwaysOn: false // B1 SKU doesn't support Always On
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistryLoginServer}'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentityClientId
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
    }
  }
}

// Note: Site extensions are not supported for Linux container apps
// Application Insights is configured via environment variables instead

// ============================================================================
// Outputs
// ============================================================================

output id string = appService.id
output name string = appService.name
output url string = 'https://${appService.properties.defaultHostName}'
output principalId string = appService.identity.userAssignedIdentities[managedIdentityId].principalId
