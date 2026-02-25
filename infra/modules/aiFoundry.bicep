// ============================================================================
// Azure AI Foundry (Cognitive Services) Module
// ============================================================================

@description('Name of the AI Foundry resource')
param name string

@description('Location for the resource')
param location string

@description('Tags to apply to resources')
param tags object

@description('Principal ID of the managed identity for role assignment')
param managedIdentityPrincipalId string

// ============================================================================
// Variables
// ============================================================================

// Cognitive Services OpenAI User role definition ID
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// ============================================================================
// Resources
// ============================================================================

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
  }
}

// GPT-4o Model Deployment (widely available)
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiFoundry
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-08-06'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

// Phi models require deployment via Azure AI Studio or Managed Compute
// They are not available in the OpenAI format for standard Cognitive Services deployments
// To add Phi models:
// 1. Go to Azure AI Studio (ai.azure.com)
// 2. Navigate to Model Catalog → Phi models
// 3. Deploy as a Managed Compute endpoint
// Or use Azure Machine Learning workspace for serverless deployment

// Cognitive Services OpenAI User role assignment for managed identity
resource openAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry.id, managedIdentityPrincipalId, cognitiveServicesOpenAIUserRoleId)
  scope: aiFoundry
  properties: {
    principalId: managedIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================

output id string = aiFoundry.id
output name string = aiFoundry.name
output endpoint string = aiFoundry.properties.endpoint
