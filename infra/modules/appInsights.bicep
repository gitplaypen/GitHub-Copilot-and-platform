// ============================================================================
// Application Insights Module
// ============================================================================

@description('Name of the Application Insights resource')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply to resources')
param tags object

@description('Log Analytics workspace ID for storing logs')
param logAnalyticsWorkspaceId string

// ============================================================================
// Resources
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    RetentionInDays: 30 // Dev environment: 30 days retention
    SamplingPercentage: 100 // Dev environment: full sampling
  }
}

// ============================================================================
// Outputs
// ============================================================================

output id string = appInsights.id
output name string = appInsights.name
output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
