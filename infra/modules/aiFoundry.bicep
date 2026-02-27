@description('Name of the Azure AI Foundry hub resource')
param name string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object = {}

// Azure AI Foundry hub - provides access to GPT-4 and Phi models available in westus3
resource aiFoundry 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Azure AI Foundry hub for ZavaStorefront - GPT-4 and Phi model access'
    friendlyName: name
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

output id string = aiFoundry.id
output name string = aiFoundry.name
