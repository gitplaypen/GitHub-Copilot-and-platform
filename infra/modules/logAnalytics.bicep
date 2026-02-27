// ============================================================================
// Log Analytics Workspace Module
// ============================================================================

@description('Name of the Log Analytics workspace')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply to resources')
param tags object

// ============================================================================
// Resources
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30 // Dev environment: 30 days retention
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1 // Dev environment: 1GB daily cap
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

output id string = logAnalytics.id
output name string = logAnalytics.name
