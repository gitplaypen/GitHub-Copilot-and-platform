# ZavaStorefront Azure Infrastructure

This directory contains Bicep infrastructure-as-code (IaC) templates for deploying the ZavaStorefront application to Azure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Resource Group (westus3)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  App Service     │───▶│  Container       │                   │
│  │  (Linux B1)      │    │  Registry (ACR)  │                   │
│  │                  │    │  Basic SKU       │                   │
│  └────────┬─────────┘    └──────────────────┘                   │
│           │                                                      │
│           │  ┌──────────────────┐    ┌──────────────────┐       │
│           └─▶│  Application     │───▶│  Log Analytics   │       │
│              │  Insights        │    │  Workspace       │       │
│              └──────────────────┘    └──────────────────┘       │
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  User Assigned   │───▶│  Azure AI        │                   │
│  │  Managed Identity│    │  Foundry (GPT-4) │                   │
│  └──────────────────┘    └──────────────────┘                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `main.bicep` | Root orchestration template (subscription scope) |
| `main.parameters.json` | Parameter file for deployment |
| `modules/identity.bicep` | User Assigned Managed Identity |
| `modules/containerRegistry.bicep` | Azure Container Registry with RBAC |
| `modules/logAnalytics.bicep` | Log Analytics Workspace |
| `modules/appInsights.bicep` | Application Insights |
| `modules/appService.bicep` | App Service Plan + Web App (Linux container) |
| `modules/aiFoundry.bicep` | Azure AI Foundry with GPT-4 and Phi models |

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.50+)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (v1.0+)
- Azure subscription with permissions to create resources
- **No local Docker installation required** - images are built using ACR Tasks

## Deployment

### Using Azure Developer CLI (Recommended)

```bash
# Initialize environment (first time only)
azd init

# Preview what will be deployed
azd provision --preview

# Deploy infrastructure and application
azd up
```

### Using Azure CLI

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>

# Deploy at subscription scope
az deployment sub create \
  --location westus3 \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --parameters environmentName=dev location=westus3
```

## Security Features

- **RBAC Authentication**: App Service authenticates to ACR using Managed Identity with AcrPull role
- **No Admin Credentials**: ACR admin user is disabled
- **No Anonymous Access**: ACR anonymous pull is disabled
- **Managed Identity**: All service-to-service authentication uses User Assigned Managed Identity
- **HTTPS Only**: App Service enforces HTTPS connections
- **TLS 1.2**: Minimum TLS version requirement

## ACR RBAC Configuration

The App Service uses a User Assigned Managed Identity to pull images from ACR:

1. **Managed Identity** is created and assigned to App Service
2. **AcrPull role** (ID: `7f951dda-4ed3-4680-a7ca-43fe172d538d`) is assigned to the Managed Identity on the Container Registry
3. App Service configuration sets:
   - `acrUseManagedIdentityCreds: true`
   - `acrUserManagedIdentityID: <managed-identity-client-id>`

## Building Container Images (No Local Docker)

Images are built using Azure Container Registry Tasks:

```bash
# Build and push using ACR Tasks
az acr build --registry <acr-name> --image zavastorefront:latest ./src
```

Or via the AZD predeploy hook (automatically runs during `azd deploy`).

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ASPNETCORE_ENVIRONMENT` | ASP.NET Core environment (Development) |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights connection string |
| `AZURE_CLIENT_ID` | Managed Identity client ID |
| `DOCKER_REGISTRY_SERVER_URL` | ACR login server URL |

## Outputs

After deployment, the following values are available:

| Output | Description |
|--------|-------------|
| `AZURE_RESOURCE_GROUP` | Resource group name |
| `AZURE_CONTAINER_REGISTRY_NAME` | ACR name |
| `AZURE_CONTAINER_REGISTRY_LOGIN_SERVER` | ACR login server |
| `AZURE_APP_SERVICE_NAME` | App Service name |
| `AZURE_APP_SERVICE_URL` | Application URL |
| `AZURE_APP_INSIGHTS_CONNECTION_STRING` | App Insights connection |
| `AZURE_AI_FOUNDRY_ENDPOINT` | AI Foundry endpoint |

## Cleanup

```bash
# Remove all resources
azd down

# Or using Azure CLI
az group delete --name rg-<environment-name> --yes
```
