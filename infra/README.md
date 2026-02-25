# ZavaStorefront – Azure Infrastructure

This folder contains Bicep templates and AZD configuration for the ZavaStorefront
development environment, deployed in the **westus3** region.

---

## Resources Provisioned

| Resource | Name pattern | Purpose |
|---|---|---|
| Resource Group | `rg-zavastore-dev-westus3` | Container for all resources |
| Log Analytics Workspace | `log-zavastore-dev` | Backing store for App Insights |
| Azure Container Registry | `zavastoreacrdev` | Docker image repository |
| App Service Plan | `asp-zavastore-dev` | Linux hosting plan (B1 SKU) |
| App Service (Web App) | `app-zavastore-dev` | Linux container host |
| Application Insights | `ai-zavastore-dev` | Monitoring and telemetry |
| Azure AI Foundry | `aif-zavastore-dev` | GPT-4 and Phi model access |

---

## Folder Structure

```
infra/
├── main.bicep                 # Root orchestration template
├── main.parameters.json       # AZD parameter file
├── README.md                  # This file
└── modules/
    ├── logAnalytics.bicep     # Log Analytics workspace
    ├── acr.bicep              # Azure Container Registry
    ├── appService.bicep       # App Service Plan + Web App
    ├── appInsights.bicep      # Application Insights
    └── aiFoundry.bicep        # Azure AI Foundry hub
```

---

## Deploy with Azure Developer CLI (AZD)

### Prerequisites

- [Azure Developer CLI (AZD)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed
- Azure CLI authenticated (`az login`)
- An Azure subscription with sufficient quota in **westus3**

> **No local Docker required.** The GitHub Actions workflow uses `az acr build`
> (ACR Tasks) to build and push container images entirely in Azure.

### Steps

```bash
# 1. Clone the repository and navigate to the root
git clone <repo-url>
cd GitHub-Copilot-and-platform

# 2. Authenticate with Azure
az login
azd auth login

# 3. (Optional) Preview the resources that will be created
azd provision --preview

# 4. Provision infrastructure
azd provision

# 5. Deploy the application
azd deploy

# Or do both in one command
azd up
```

During `azd provision` you will be prompted for:
- **Environment name** – e.g. `dev`
- **Azure subscription**
- **Azure location** – choose `westus3`

---

## App Service → ACR Authentication (RBAC, No Passwords)

The Web App uses a **system-assigned managed identity** and the built-in
`AcrPull` RBAC role to authenticate to ACR.  
No admin credentials or passwords are stored anywhere.

The role assignment is defined in `main.bicep` and scoped directly to the ACR resource
(not the resource group) to follow the principle of least privilege:

```bicep
// Reference the ACR resource so the role assignment can be scoped to it
resource existingAcr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acr.outputs.name
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.outputs.id, appService.outputs.principalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: existingAcr   // ← scoped to the ACR resource only
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'   // AcrPull
    )
    principalId: appService.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}
```

`acrUseManagedIdentityCreds: true` is set in the App Service site config so
that the platform uses the managed identity to pull images automatically.

---

## Application Insights Integration

The App Service is pre-configured with the Application Insights connection
string via an app setting (`APPLICATIONINSIGHTS_CONNECTION_STRING`).  
The auto-instrumentation agent (`ApplicationInsightsAgent_EXTENSION_VERSION`)
is also enabled, so telemetry flows without any code changes.

To view telemetry:
1. Open the Azure Portal → **Application Insights** resource `ai-zavastore-dev`
2. Navigate to **Live Metrics**, **Failures**, or **Performance** blades.

---

## Azure AI Foundry (GPT-4 and Phi)

An Azure AI Foundry Hub (`aif-zavastore-dev`) is provisioned in **westus3**,
where GPT-4 and Phi models are available.

After provisioning:
1. Open the Azure Portal → **Azure AI Foundry** resource.
2. Deploy models (GPT-4, Phi) from the **Model catalog** inside the hub.
3. Use the generated endpoint URL and API key (or managed identity) in your
   application settings.

For LLM workloads, connect your app using the Azure AI SDK:
```bash
pip install azure-ai-inference  # Python example
```

---

## GitHub Actions Workflow (No Local Docker)

The workflow at `.github/workflows/azure-deploy.yml` uses `az acr build` to
build and push images using **ACR Tasks**, which run entirely in Azure —
no Docker installation is needed on the developer's machine or the runner.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | JSON output of `az ad sp create-for-rbac --json-auth` |

### Required GitHub Variables

| Variable | Description |
|---|---|
| `AZURE_CONTAINER_REGISTRY_NAME` | ACR name without `.azurecr.io` suffix |
| `AZURE_APP_SERVICE_NAME` | App Service name |

To create the service principal:
```bash
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name} \
  --json-auth
```

Also assign `AcrPush` so the service principal can push images:
```bash
az role assignment create \
  --assignee {sp-client-id} \
  --role AcrPush \
  --scope /subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.ContainerRegistry/registries/{acr-name}
```

---

## Security Notes

- Admin credentials are **disabled** on ACR (`adminUserEnabled: false`)
- App Service pulls images via managed identity (`AcrPull` role), not passwords
- All secrets stay in Azure and GitHub Secrets — none are committed to code
- `httpsOnly: true` is enforced on the App Service
