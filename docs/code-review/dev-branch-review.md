# Code Review: `dev` → `main`

**Reviewer:** GitHub Copilot  
**Branch reviewed:** `dev`  
**Compared against:** `main`  
**Review date:** 2026-02-25

---

## Summary

This review covers the infrastructure-as-code, GitHub Actions workflow, Docker configuration, and application changes introduced in the `dev` branch. The work represents a complete, end-to-end Azure deployment solution for the ZavaStorefront .NET application using Bicep, AZD, and GitHub Actions.

**Overall verdict:** The code is well-structured and follows many security best practices (Managed Identity, RBAC, no hardcoded secrets). The items below must be addressed before merging to `main`.

---

## Files Reviewed

| File | Status | Notes |
|---|---|---|
| `.github/workflows/azure-deploy.yml` | ⚠️ Issues | See findings below |
| `infra/main.bicep` | ✅ Approved | Clean, subscription-scoped |
| `infra/main.json` | ❌ Must fix | Compiled artifact – should not be committed |
| `infra/main.parameters.json` | ✅ Approved | Uses AZD variable substitution |
| `infra/modules/identity.bicep` | ✅ Approved | |
| `infra/modules/containerRegistry.bicep` | ⚠️ Note | AcrPull only – deployer also needs AcrPush |
| `infra/modules/appService.bicep` | ⚠️ Note | `ASPNETCORE_ENVIRONMENT` hardcoded |
| `infra/modules/appInsights.bicep` | ✅ Approved | |
| `infra/modules/logAnalytics.bicep` | ✅ Approved | |
| `infra/modules/aiFoundry.bicep` | ✅ Approved | |
| `azure.yaml` | ✅ Approved | AZD hooks avoid local Docker requirement |
| `src/Dockerfile` | ⚠️ Note | .NET 6.0 is EOL |
| `src/.dockerignore` | ✅ Approved | Excludes secrets correctly |
| `src/ZavaStorefront.csproj` | ✅ Approved | |

---

## Findings

### 🔴 Critical

#### 1. `infra/main.json` must not be committed

**File:** `infra/main.json`

`main.json` is the compiled ARM template generated from `main.bicep`. Committing it creates multiple problems:

- The JSON file and the Bicep source can become out of sync, silently deploying stale infrastructure.
- The file is ~870 lines of machine-generated JSON, making diffs unreadable in PRs.
- The correct approach is to let `az deployment` or `azd` compile Bicep at deploy time.

**Action required:** Remove `infra/main.json` from the repository and add a `.gitignore` rule to prevent it from being committed again.

```bash
git rm --cached infra/main.json
echo "infra/main.json" >> .gitignore
```

---

### 🟠 High

#### 2. Workflow `permissions` block is missing

**File:** `.github/workflows/azure-deploy.yml`

The workflow does not declare a `permissions:` block. Without it, the job inherits the repository's default token permissions, which are often wider than necessary.

**Action required:** Add a minimal permissions block to the workflow:

```yaml
permissions:
  contents: read
  id-token: write   # required if/when switching to OIDC
```

#### 3. Deployment runs on every pull request

**File:** `.github/workflows/azure-deploy.yml`

```yaml
on:
  pull_request:
    branches: [ '*' ]
```

The `build-and-deploy` job pushes images **and** deploys to App Service on every pull request to any branch. This means:

- A PR from a fork or feature branch to any branch triggers a production-registry push.
- The deployment step runs on PRs, so a PR can change the live environment before review is complete.

**Action required:** Split the single job into two jobs using a `needs:` dependency:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    # runs on push AND pull_request
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: az acr login --name ${{ vars.AZURE_CONTAINER_REGISTRY_NAME }}
      - name: Build Docker image
        run: docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} ./src

  deploy:
    runs-on: ubuntu-latest
    needs: build
    # Only deploy on push to main, not on PRs
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: az acr login --name ${{ vars.AZURE_CONTAINER_REGISTRY_NAME }}
      - name: Build and push Docker image
        run: |
          docker build \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest \
            ./src
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
      - uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ env.APP_NAME }}
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

---

### 🟡 Medium

#### 4. AcrPush role is not assigned to the deployer identity

**File:** `infra/modules/containerRegistry.bicep`

The module assigns only the `AcrPull` role to the managed identity (correct for App Service). However, the GitHub Actions service principal (referenced by `secrets.AZURE_CREDENTIALS`) also requires `AcrPush` to push images to the registry. This role is not provisioned in the Bicep templates.

If `AZURE_CREDENTIALS` was created with `--role contributor` on the resource group, it may already have `AcrPush` access transitively, but this is implicit and may change. It is better to make the permission explicit in IaC.

**Recommendation:** Add an `AcrPush` role assignment for the service principal in `containerRegistry.bicep`, or document clearly that the service principal must be granted `AcrPush` separately.

#### 5. Consider migrating to OIDC (keyless) authentication

**File:** `.github/workflows/azure-deploy.yml`

The workflow uses `AZURE_CREDENTIALS` (a service principal JSON secret). The repository already has a prompt file at `.github/prompts/OIDC_Credentials_for_github.prompt.md` that references switching to federated OIDC credentials.

OIDC is preferred because:
- No long-lived secret to rotate or leak.
- Tokens are scoped to a specific branch/PR, not the whole repository.

**Recommendation:** Follow the OIDC prompt to replace `AZURE_CREDENTIALS` with the three short-lived secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) and add `id-token: write` to the workflow permissions.

---

### 🟢 Low / Suggestions

#### 6. `ASPNETCORE_ENVIRONMENT` is hardcoded to `'Development'`

**File:** `infra/modules/appService.bicep`

```bicep
{
  name: 'ASPNETCORE_ENVIRONMENT'
  value: 'Development'
}
```

This is the `dev` branch, so `'Development'` is correct for now. However, if the template is ever used to provision a staging or production environment, this setting must be changed. Consider accepting this as a parameter to avoid accidentally deploying `'Development'` mode to production.

**Recommendation:** Add an `@allowed(['Development', 'Staging', 'Production'])` parameter with a default of `'Development'`.

#### 7. Base image is .NET 6.0 (end-of-life)

**File:** `src/Dockerfile`

.NET 6.0 reached end-of-life in November 2024 and no longer receives security patches.

**Recommendation:** Upgrade to .NET 8.0 (LTS, supported until November 2026) or .NET 9.0 (current, supported until May 2026):

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
...
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
```

Also update `src/ZavaStorefront.csproj` to target `net8.0`.

---

## What's Done Well ✅

- **Managed Identity everywhere** – No passwords or admin keys are used for ACR-to-App Service authentication.
- **`adminUserEnabled: false`** on the container registry enforces RBAC.
- **`httpsOnly: true`**, **`ftpsState: 'Disabled'`**, and **`minTlsVersion: '1.2'`** are all set correctly on the App Service.
- **`src/.dockerignore`** is comprehensive and explicitly excludes secrets files.
- **AZD hooks** build container images using ACR Tasks, eliminating the need for local Docker.
- **`uniqueString()` naming** prevents resource name collisions across environments.
- **Resource tagging** is applied consistently to all resources.
- **`infra/README.md`** documents the deployment process clearly.

---

## Action Items Before Merge

| # | Severity | Action |
|---|---|---|
| 1 | 🔴 Critical | Remove `infra/main.json` from the repo; add to `.gitignore` |
| 2 | 🟠 High | Add `permissions:` block to `azure-deploy.yml` |
| 3 | 🟠 High | Separate build (all events) from deploy (push to main only) |
| 4 | 🟡 Medium | Explicitly assign AcrPush to the deployer principal in Bicep |
| 5 | 🟡 Medium | Migrate to OIDC authentication for GitHub Actions |
| 6 | 🟢 Low | Parameterize `ASPNETCORE_ENVIRONMENT` in `appService.bicep` |
| 7 | 🟢 Low | Upgrade base image to .NET 8.0 |
