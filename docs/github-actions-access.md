# Granting GitHub Actions Access to This Repository

This document explains how to configure GitHub so that the ACR deployment workflow can run securely, and how to grant collaborator access to the repository.

---

## 1. Enable GitHub Actions

1. Go to your repository on GitHub.
2. Click **Settings** → **Actions** → **General**.
3. Under **Actions permissions**, select **Allow all actions and reusable workflows** (or restrict to trusted sources as your organization requires).
4. Under **Workflow permissions**, select **Read repository contents and packages permissions** (the workflows in this repo only need read access to source code).
5. Click **Save**.

---

## 2. Configure Required Secrets

The `deploy-to-acr.yml` workflow reads four secrets. Add them at **Settings** → **Secrets and variables** → **Actions** → **Secrets** tab.

| Secret name | Value |
|---|---|
| `AZURE_CREDENTIALS` | JSON output from `az ad sp create-for-rbac` (see below) |
| `ACR_NAME` | Short name of your Azure Container Registry, e.g. `myregistry` |
| `ACR_LOGIN_SERVER` | Full login server, e.g. `myregistry.azurecr.io` |
| `IMAGE_NAME` | Docker image name to push, e.g. `zava-storefront` |

> **Important:** Never paste secret values into workflow YAML files or commit them to source control. Always use `${{ secrets.SECRET_NAME }}` references.

### Creating the Azure service principal

```bash
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name} \
  --json-auth
```

Copy the entire JSON output and save it as the `AZURE_CREDENTIALS` secret.

### Granting AcrPush permission to the service principal

```bash
az role assignment create \
  --assignee {service-principal-client-id} \
  --role AcrPush \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}/providers/Microsoft.ContainerRegistry/registries/{acr-name}
```

---

## 3. Keep `.env` Files Out of the Repository

The `.gitignore` at the root of this repository already excludes:

```
.env
.env.*
```

These patterns match `.env` files anywhere in the repository tree, including `src/.env`. **Never remove these rules or force-add an `.env` file with `git add -f`.**

---

## 4. Recommended OIDC Permissions (Optional Hardening)

For improved security, you can replace the `AZURE_CREDENTIALS` service principal secret with keyless OIDC federation:

1. Create a federated identity credential on your Azure App Registration that trusts the GitHub Actions OIDC issuer for your repository and `main` branch.
2. Replace the `azure/login@v2` step in the workflow with:

```yaml
- name: Log in to Azure (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

3. Add `id-token: write` to the workflow's `permissions` block.
4. Remove the `AZURE_CREDENTIALS` secret once OIDC login is confirmed working.

---

## 5. Granting Collaborator Access

To give a person or team push access to the repository:

1. Go to **Settings** → **Manage access**.
2. Click **Add people** or **Add teams**.
3. Search for the GitHub username or team name and select the appropriate role:
   - **Write** – can push branches and open pull requests.
   - **Maintain** – can manage issues, PRs, and some settings.
   - **Admin** – full repository administration (use sparingly).
4. Click **Add** to confirm.

> Collaborators with at minimum **Write** access can trigger workflows manually via `workflow_dispatch`, but secrets are never exposed in logs.
