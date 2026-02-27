// ============================================================================
// Azure Container Registry Module
// ============================================================================

@description('Name of the container registry')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply to resources')
param tags object

@description('Principal ID of the managed identity for AcrPull role assignment')
param managedIdentityPrincipalId string

// ============================================================================
// Variables
// ============================================================================

// AcrPull role definition ID
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// ============================================================================
// Resources
// ============================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false // Security: Using RBAC instead of admin credentials
    anonymousPullEnabled: false // Security: No anonymous access
    publicNetworkAccess: 'Enabled'
    policies: {
      retentionPolicy: {
        status: 'disabled'
      }
    }
  }
}

// AcrPull role assignment for managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentityPrincipalId, acrPullRoleId)
  scope: containerRegistry
  properties: {
    principalId: managedIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
