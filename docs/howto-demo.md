# Umbrella demo — setup and run guide

## Contents

- [Umbrella demo — setup and run guide](#umbrella-demo--setup-and-run-guide)
  - [Contents](#contents)
  - [1. Prerequisites](#1-prerequisites)
  - [2. One-time Azure setup](#2-one-time-azure-setup)
    - [2a. Create the resource group](#2a-create-the-resource-group)
    - [2b. Create a service principal and configure OIDC for GitHub Actions](#2b-create-a-service-principal-and-configure-oidc-for-github-actions)
    - [2c. Note your own AAD object ID (for the Key Vault admin access policy)](#2c-note-your-own-aad-object-id-for-the-key-vault-admin-access-policy)
    - [2d. Create a second service principal for the Key Vault enumeration demo](#2d-create-a-second-service-principal-for-the-key-vault-enumeration-demo)
  - [3. One-time GitHub setup](#3-one-time-github-setup)
    - [3a. Create a `broken` branch](#3a-create-a-broken-branch)
    - [3b. Add repository secrets](#3b-add-repository-secrets)
    - [3c. Add repository variables](#3c-add-repository-variables)
    - [3d. Connect the repository to Defender for Cloud (for the DevOps demo)](#3d-connect-the-repository-to-defender-for-cloud-for-the-devops-demo)
  - [4. Deploy the broken baseline](#4-deploy-the-broken-baseline)
    - [4a. Trigger the deploy workflow](#4a-trigger-the-deploy-workflow)
    - [4b. Confirm resources are created](#4b-confirm-resources-are-created)
    - [4c. Retrieve the APIM gateway URL](#4c-retrieve-the-apim-gateway-url)
    - [4d. Get the Static Web Apps deployment token and save it](#4d-get-the-static-web-apps-deployment-token-and-save-it)
    - [4e. Confirm the app is working](#4e-confirm-the-app-is-working)
  - [5. Enable Defender for Cloud plans](#5-enable-defender-for-cloud-plans)
  - [6. Verify the app is live](#6-verify-the-app-is-live)
  - [7. Demo: SQL injection — Defender for Databases](#7-demo-sql-injection--defender-for-databases)
  - [8. Demo: Malware upload — Defender for Storage](#8-demo-malware-upload--defender-for-storage)
  - [9. Demo: API burst — Defender for APIs](#9-demo-api-burst--defender-for-apis)
  - [10. Demo: Key Vault enumeration — Defender for Key Vault](#10-demo-key-vault-enumeration--defender-for-key-vault)
  - [11. Demo: Shell execution — Defender for App Service](#11-demo-shell-execution--defender-for-app-service)
  - [12. Demo: DevOps findings — Defender for DevOps / GHAS](#12-demo-devops-findings--defender-for-devops--ghas)
  - [13. Demo: CSPM — Secure Score and attack paths](#13-demo-cspm--secure-score-and-attack-paths)
  - [14. Switching to the fixed version (live remediation)](#14-switching-to-the-fixed-version-live-remediation)
    - [Option A — push to main (full redeploy, ~10 minutes)](#option-a--push-to-main-full-redeploy-10-minutes)
    - [Option B — deployment slot swap (near-instant, recommended for live demos)](#option-b--deployment-slot-swap-near-instant-recommended-for-live-demos)
  - [15. Tear-down](#15-tear-down)
  - [Quick-reference: alert timing](#quick-reference-alert-timing)
  - [Troubleshooting](#troubleshooting)

---

## 1. Prerequisites

| Tool | Minimum version | Check |
|---|---|---|
| Azure CLI | 2.60 | `az version` |
| .NET SDK | 10.0 | `dotnet --version` |
| Git | any | `git --version` |
| GitHub account | — | — |
| Azure subscription | — | Contributor or Owner on a non-production subscription |

Install missing tools:

```bash
# Azure CLI (Windows)
winget install Microsoft.AzureCLI

# .NET 10 SDK
winget install Microsoft.DotNet.SDK.10
```

Log in to Azure:

```bash
az login
az account set --subscription "<your subscription name or ID>"
```

---

## 2. One-time Azure setup

### 2a. Create the resource group

```bash
az group create `
  --name rg-umbrella-demo `
  --location westeurope
```

### 2b. Create a service principal and configure OIDC for GitHub Actions

Create the service principal:

```bash
az ad sp create-for-rbac `
  --name sp-umbrella-github `
  --role Contributor `
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-umbrella-demo
```

Note the `appId` (client ID) and `tenant` values from the output.

Add federated identity credentials for each branch that triggers the workflow:

```powershell
# For the 'main' branch
az ad app federated-credential create `
  --id <APP_ID> `
  --parameters '{"name":"github-main","issuer":"https://token.actions.githubusercontent.com","subject":"repo:Ba4bes/Umbrella:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"]}'

# For the 'broken' branch
az ad app federated-credential create `
  --id <APP_ID> `
  --parameters '{"name":"github-broken","issuer":"https://token.actions.githubusercontent.com","subject":"repo:Ba4bes/Umbrella:ref:refs/heads/broken","audiences":["api://AzureADTokenExchange"]}'
```

Save the `appId`, `tenant`, and your subscription ID — you will use them as secrets in step 3.

### 2c. Note your own AAD object ID (for the Key Vault admin access policy)

```bash
az ad signed-in-user show --query id -o tsv
```

Save this value; you will use it as `KV_ADMIN_OBJECT_ID`.

### 2d. Create a second service principal for the Key Vault enumeration demo

This SP needs **no permissions** — its failed access is what triggers the Defender for Key Vault alert.

```bash
az ad sp create-for-rbac `
  --name sp-umbrella-kv-attacker `
  --role Reader `
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-umbrella-demo
```

Save the `appId` and `password` — you will use them in demo step 10.

---

## 3. One-time GitHub setup

### 3a. Create a `broken` branch

The deploy workflow uses branch name to select the Bicep variant.

```bash
git checkout -b broken
git push -u origin broken
```

### 3b. Add repository secrets

Go to **Settings → Secrets and variables → Actions → Secrets** and add:

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `appId` from step 2b |
| `AZURE_TENANT_ID` | `tenant` from step 2b |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `SQL_ADMIN_PASSWORD` | A strong password (min 12 chars, upper + lower + number + symbol) |
| `KV_ADMIN_OBJECT_ID` | Object ID from step 2c |
| `SWA_DEPLOYMENT_TOKEN` | Leave blank for now — you will fill it after the first Bicep deploy (step 4d) |

Or use the GitHub CLI (prompts for each value interactively):

```bash
gh secret set AZURE_CLIENT_ID
gh secret set AZURE_TENANT_ID
gh secret set AZURE_SUBSCRIPTION_ID
gh secret set SQL_ADMIN_PASSWORD
gh secret set KV_ADMIN_OBJECT_ID
gh secret set SWA_DEPLOYMENT_TOKEN   # leave blank for now; update after step 4d
```

Alternatively, populate all secrets at once from a `.env` file:

```bash
gh secret set --env-file .env
```

### 3c. Add repository variables

Go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable name | Value |
|---|---|
| `AZURE_RG` | `rg-umbrella-demo` |
| `AZURE_WEBAPP_NAME` | `umbrella-api` (must match the `prefix` parameter in the Bicep files) |

Or use the GitHub CLI:

```bash
gh variable set AZURE_RG --body "rg-umbrella-demo"
gh variable set AZURE_WEBAPP_NAME --body "umbrella-api"
```

### 3d. Connect the repository to Defender for Cloud (for the DevOps demo)

1. In the Azure Portal open **Defender for Cloud → Environment settings**.
2. Select **Add environment → GitHub**.
3. Follow the wizard to authorise Defender for Cloud to read your repository.
4. Ensure the `Ba4bes/Umbrella` repository is in scope.

---

## 4. Deploy the broken baseline

### 4a. Trigger the deploy workflow

```bash
git checkout broken
git commit --allow-empty -m "chore: trigger broken baseline deploy"
git push
```

Or trigger the workflow directly without a commit:

```bash
gh workflow run deploy.yml --ref broken
```

This triggers `.github/workflows/deploy.yml`, which:

1. Builds and publishes the .NET 10 app.
2. Deploys `infra/broken.bicep` to `rg-umbrella-demo`.
3. Zip-deploys the app to the App Service.
4. Deploys the frontend to Static Web Apps.

Watch progress at **GitHub → Actions**, or follow it in the terminal:

```bash
gh run watch
```

### 4b. Confirm resources are created

```bash
az resource list `
  --resource-group rg-umbrella-demo `
  --output table
```

You should see: App Service plan, App Service, Static Web App, SQL Server, SQL Database, Storage Account, Key Vault, and API Management.

> **APIM note:** The Developer SKU takes 30–45 minutes to provision on first deploy. The workflow will wait. Plan ahead.

### 4c. Retrieve the APIM gateway URL

```bash
az apim show `
  --name umbrella-apim `
  --resource-group rg-umbrella-demo `
  --query gatewayUrl `
  --output tsv
```

### 4d. Get the Static Web Apps deployment token and save it

```bash
az staticwebapp secrets list `
  --name umbrella-swa `
  --resource-group rg-umbrella-demo `
  --query "properties.apiKey" `
  --output tsv
```

Paste this value into the `SWA_DEPLOYMENT_TOKEN` GitHub secret (Settings → Secrets), then re-run the workflow (Actions → Deploy Umbrella → Re-run all jobs) so the frontend deploys with the token.

Or use the GitHub CLI:

```bash
SWA_TOKEN=$(az staticwebapp secrets list \
  --name umbrella-swa \
  --resource-group rg-umbrella-demo \
  --query "properties.apiKey" \
  --output tsv)

gh secret set SWA_DEPLOYMENT_TOKEN --body "$SWA_TOKEN"
gh run rerun --failed
```

### 4e. Confirm the app is working

```bash
# Health check
curl https://umbrella-api.azurewebsites.net/health

# Expected:
# {"status":"healthy","utc":"..."}
```

Open the Static Web App URL in a browser and submit a few words to confirm the word cloud renders.

---

## 5. Enable Defender for Cloud plans

All plans must be on **before** the demo triggers will generate alerts.

1. In the Azure Portal open **Defender for Cloud → Environment settings**.
2. Select your subscription.
3. Enable the following plans:

| Plan | Setting |
|---|---|
| Defender for Servers | Off (not needed for this demo) |
| Defender for App Service | **On** |
| Defender for Databases — Azure SQL | **On** |
| Defender for Storage | **On** |
| Defender for Key Vault | **On** |
| Defender for APIs | **On** (requires APIM to already exist) |
| Defender CSPM | **On** |

4. Click **Save**.
5. Under **DevOps security**, confirm the GitHub environment from step 3d is connected.

> Allow 10–15 minutes after enabling plans before running demo triggers — the monitoring agents need time to initialise.

---

## 6. Verify the app is live

Run this checklist the morning of the demo:

```bash
APIM_URL="https://umbrella-apim.azure-api.net"
APP_URL="https://umbrella-api.azurewebsites.net"

# Backend health
curl -s "$APP_URL/health" | python3 -m json.tool

# API via APIM
curl -s "$APIM_URL/words" | python3 -m json.tool

# Debug endpoint active (broken baseline only)
curl -s "$APP_URL/debug/exec?cmd=echo+ready"
```

Open the SWA URL in a browser. Submit a word. Confirm it appears in the cloud within ~3 seconds.

---

## 7. Demo: SQL injection — Defender for Databases

**What it shows:** Defender for Databases detects a SQL injection attack pattern in real time.

**Expected alert:** `Potential SQL injection` — fires within ~2 minutes.

**Steps:**

1. Open the word-cloud app in the browser (share screen / project it).
2. In the word input box, type exactly:
   ```
   '; DROP TABLE Words;--
   ```
3. Click **Submit**.
4. Switch to the Azure Portal tab.
5. Open **Defender for Cloud → Security alerts**.
6. The alert `Potential SQL injection` will appear. Click it to show:
   - The offending query text.
   - The affected SQL Server resource.
   - The recommended remediation (use parameterised queries).

**Talking point:** The table is not actually dropped because the backend uses a connection string with a limited-privilege SQL login. The alert fires on the *pattern*, not the *outcome* — this is behavioural detection, not signature matching.

---

## 8. Demo: Malware upload — Defender for Storage

**What it shows:** Defender for Storage scans blobs on upload and detects the industry-standard EICAR test file.

**Expected alert:** `Malicious file uploaded to storage account` — fires within ~60 seconds.

**Steps:**

1. In the Azure Portal open **Storage accounts → umbrellastoreXX → Containers → assets**.
2. Click **Upload**.
3. Create a local file named `test.txt` with this exact content (no trailing newline):
   ```
   X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
   ```
   Or download it directly:
   ```bash
   curl -o eicar.txt https://secure.eicar.org/eicar.com.txt
   ```
4. Upload the file to the container.
5. Wait ~60 seconds.
6. Open **Defender for Cloud → Security alerts**.
7. Show the `Malicious file uploaded to storage account` alert.

**Talking point:** EICAR is a harmless industry test string — it contains no malware. Defender for Storage scans every blob on ingestion using Microsoft Defender Antivirus. The public container misconfiguration (misconfig #1) is also visible in the Secure Score at this point.

---

## 9. Demo: API burst — Defender for APIs

**What it shows:** Defender for APIs detects an anomalous traffic spike and missing authentication on the APIM gateway.

**Expected alert:** `Spike in API traffic` — fires within ~5 minutes of the burst.

**Steps:**

1. Open Azure Cloud Shell (bash) in the Portal, or use a local terminal.
2. Set your APIM URL:
   ```bash
   APIM_URL="https://umbrella-apim.azure-api.net"
   ```
3. Run the burst:
   ```bash
   for i in $(seq 1 200); do
     curl -s -o /dev/null "$APIM_URL/words"
   done
   echo "Burst complete"
   ```
4. Open **Defender for Cloud → Security alerts** and wait.
5. Show the API anomaly alert. Click through to the APIM resource to show there is no rate-limiting policy and no subscription key required (misconfigs #5).

**Talking point:** In the fixed version, a rate-limit policy (30 calls / 60 s) blocks the burst before it reaches the backend, and every call requires a subscription key.

---

## 10. Demo: Key Vault enumeration — Defender for Key Vault

**What it shows:** Defender for Key Vault alerts on a failed secret-listing attempt from an unknown principal.

**Expected alert:** `Unusual access to a Key Vault from a suspicious application` — fires within ~5 minutes.

**Steps:**

1. Log in as the attacker service principal created in step 2d:
   ```bash
   az login --service-principal `
     --username "<attacker-sp-appId>" `
     --password "<attacker-sp-password>" `
     --tenant "<your-tenant-id>"
   ```
2. Attempt to list secrets:
   ```bash
   az keyvault secret list `
     --vault-name umbrella-kv `
     --output table
   ```
   The command will fail with `Caller is not authorized` — that is expected.
3. Log back in with your normal account:
   ```bash
   az login
   ```
4. Open **Defender for Cloud → Security alerts**.
5. Show the Key Vault alert. Note that it captures the caller object ID, IP address, and the vault targeted.

**Talking point:** The alert fires even though the enumeration failed. Defender for Key Vault monitors the Azure audit plane, not just successful reads.

---

## 11. Demo: Shell execution — Defender for App Service

**What it shows:** Defender for App Service detects a suspicious process spawned by the web application.

**Expected alert:** `Suspicious process execution detected` — fires within ~2 minutes.

**Steps:**

1. Open a browser or use `curl` to hit the debug endpoint:
   ```bash
   curl "https://umbrella-api.azurewebsites.net/debug/exec?cmd=whoami"
   ```
   Expected response:
   ```json
   {"stdout":"app\n","stderr":"","exitCode":0}
   ```
2. Try a second, more obviously suspicious command:
   ```bash
   curl "https://umbrella-api.azurewebsites.net/debug/exec?cmd=cat+/etc/passwd"
   ```
3. Open **Defender for Cloud → Security alerts**.
4. Show the `Suspicious process execution detected` alert. Click through to see:
   - The process name (`sh`), its parent (`dotnet`), and the command line.
   - The App Service resource.
   - The recommended action (remove the endpoint, enable HTTPS, enable MI).

**Talking point:** This endpoint is gated on the `ENABLE_DEBUG_EXEC=true` app setting, which is set in `broken.bicep` and absent in `fixed.bicep`. The fixed slot has no `/debug/exec` route at all.

> Do not run destructive commands (`rm -rf`, etc.) — the App Service plan is shared and you will need it for the rest of the demo.

---

## 12. Demo: DevOps findings — Defender for DevOps / GHAS

**What it shows:** Defender for DevOps surfaces Bicep IaC misconfigurations and a vulnerable NuGet package directly in the GitHub Security tab and the Defender for Cloud DevOps blade.

**No live trigger needed** — findings are already present after the first push to the `broken` branch.

**Steps:**

1. In GitHub, open **Security → Code scanning alerts**.
   - Show the CodeQL finding: `Database query built from user-controlled sources` in [backend/UmbrellaApi/Program.cs](../backend/UmbrellaApi/Program.cs).

   Or via the GitHub CLI:

   ```bash
   gh api repos/Ba4bes/Umbrella/code-scanning/alerts \
     --jq '.[] | {number,rule_id:.rule.id,severity:.rule.severity,file:.most_recent_instance.location.path}'
   ```

2. Open **Security → Dependabot alerts**.
   - Show the `Newtonsoft.Json 12.0.3` alert for CVE-2024-21907 (ReDoS, high severity).
   - Note the fix: upgrade to ≥ 13.0.1.

   Or via the GitHub CLI:

   ```bash
   gh api repos/Ba4bes/Umbrella/dependabot/alerts \
     --jq '.[] | {number,package:.dependency.package.name,severity:.security_vulnerability.severity,summary:.security_advisory.summary}'
   ```

3. Open **Security → Code scanning alerts** and filter by tool `MSDO` (or `Checkov`).
   - Show the IaC findings on [infra/broken.bicep](../infra/broken.bicep):
     - Public blob container access.
     - SQL firewall open to `0.0.0.0/0`.
     - App Service HTTPS not enforced.
     - No diagnostic settings.

   Or via the GitHub CLI:

   ```bash
   gh api repos/Ba4bes/Umbrella/code-scanning/alerts -f tool_name=Checkov \
     --jq '.[] | {number,rule_id:.rule.id,file:.most_recent_instance.location.path}'
   ```

4. In the Azure Portal open **Defender for Cloud → DevOps security**.
   - Show the same findings surfaced from GitHub, with links back to the file and line number.
   - Show the CSPM integration: IaC findings are reflected in the Secure Score.

**Talking point:** These findings were detected *before* the infrastructure was deployed — shift-left security. The IaC scan runs on every push to `broken` or `main` via `.github/workflows/security.yml`.

---

## 13. Demo: CSPM — Secure Score and attack paths

**What it shows:** Defender CSPM aggregates all misconfigs into a Secure Score and draws attack paths across resources.

**No trigger needed** — populated by the broken baseline deployment.

**Steps:**

1. Open **Defender for Cloud → Secure Score**.
   - Show the overall score (it will be low due to the broken baseline).
   - Click **View recommendations** to show the full list of active findings.

2. Open **Defender for Cloud → Attack path analysis**.
   - Look for a path that connects: Internet → public Storage blob → SQL Server (the open firewall makes the DB reachable from the same network segment as the public blob).
   - Explain how an attacker could exfiltrate data stored in the SQL DB via the over-privileged path.

3. Open **Defender for Cloud → Recommendations**.
   - Filter by resource group `rg-umbrella-demo`.
   - Walk through the top recommendations: enable HTTPS, remove public blob access, restrict SQL firewall, enable Managed Identity.

---

## 14. Switching to the fixed version (live remediation)

Run this on stage to show the Secure Score improving and alerts resolving.

### Option A — push to main (full redeploy, ~10 minutes)

```bash
git checkout main
git merge broken --no-ff -m "fix: apply Defender for Cloud remediations"
git push
```

This triggers the `deploy.yml` workflow with `fixed.bicep`, which:
- Enables HTTPS and TLS 1.2 on the App Service.
- Removes the open SQL firewall rule.
- Makes the blob container private.
- Enables the system-assigned Managed Identity and adds the Key Vault access policy.
- Sets the connection string to a Key Vault reference.
- Adds Log Analytics diagnostic settings to all resources.
- Adds the APIM rate-limiting policy.
- Does **not** set `ENABLE_DEBUG_EXEC`.

### Option B — deployment slot swap (near-instant, recommended for live demos)

```bash
# Pre-stage the fixed version in a staging slot
az webapp deployment slot create `
  --name umbrella-api `
  --resource-group rg-umbrella-demo `
  --slot staging

# Deploy fixed build to staging slot
az webapp deploy `
  --name umbrella-api `
  --resource-group rg-umbrella-demo `
  --slot staging `
  --src-path app.zip `
  --type zip

# Swap slots live on stage
az webapp deployment slot swap `
  --name umbrella-api `
  --resource-group rg-umbrella-demo `
  --slot staging `
  --target-slot production
```

After the swap, open **Defender for Cloud → Secure Score** and press **Refresh** to show the score climbing.

---

## 15. Tear-down

Delete all resources when the demo is finished to avoid ongoing costs.

```bash
az group delete `
  --name rg-umbrella-demo `
  --yes `
  --no-wait
```

Also clean up the AAD service principals:

```bash
az ad sp delete --id "<sp-umbrella-github-appId>"
az ad sp delete --id "<sp-umbrella-kv-attacker-appId>"
```

---

## Quick-reference: alert timing

| Demo | Trigger action | Typical alert latency |
|---|---|---|
| SQL injection | Submit payload in word form | 1–3 min |
| Malware upload | Upload EICAR blob | ~60 s |
| API burst | 200-request loop | 3–5 min |
| Key Vault enumeration | `az keyvault secret list` (denied) | 3–5 min |
| App Service shell | `GET /debug/exec?cmd=whoami` | 1–3 min |
| DevOps findings | Already present after first push | Instant |
| CSPM | Already present after deployment | Instant |

---

## Troubleshooting

**App Service returns 503 on startup**
- Check that `DOTNETCORE|10.0` is available in the chosen region: `az webapp list-runtimes --os linux | grep DOTNETCORE`.
- Fall back to self-contained publish if the image is not yet available: add `<SelfContained>true</SelfContained>` and `<RuntimeIdentifier>linux-x64</RuntimeIdentifier>` to the `.csproj`.

**APIM returns 401 on the broken baseline**
- Confirm `subscriptionRequired: false` is set. The APIM Developer SKU sometimes takes up to 45 minutes to fully propagate policy changes after first deploy.

**No Defender alerts appearing**
- Verify all Defender plans are **On** in Environment settings (step 5).
- Wait 10–15 minutes after enabling a plan before running the trigger.
- Check that the resource group `rg-umbrella-demo` is in scope for the plan.

**`/debug/exec` returns 404**
- Confirm the `ENABLE_DEBUG_EXEC` app setting is `true` in the App Service configuration: `az webapp config appsettings list --name umbrella-api --resource-group rg-umbrella-demo`.

**GitHub Actions deploy fails with OIDC / login error**
- Confirm `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` secrets are set correctly.
- Verify that a federated credential exists for the exact branch being pushed to (check with `az ad app federated-credential list --id <APP_ID>`).
- Ensure the workflow job has `permissions: id-token: write` — this is required for OIDC token issuance.
