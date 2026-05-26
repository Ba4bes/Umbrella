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
    - [5a. Confirm the APIM API is onboarded to Defender for APIs](#5a-confirm-the-apim-api-is-onboarded-to-defender-for-apis)
  - [6. Verify the app is live](#6-verify-the-app-is-live)
  - [7. Demo: SQL injection — Defender for Databases](#7-demo-sql-injection--defender-for-databases)
  - [8. Demo: Malware upload — Defender for Storage](#8-demo-malware-upload--defender-for-storage)
  - [9. Demo: API burst — Defender for APIs](#9-demo-api-burst--defender-for-apis)
  - [10. Demo: Key Vault enumeration — Defender for Key Vault](#10-demo-key-vault-enumeration--defender-for-key-vault)
  - [11. Demo: Shell execution — Defender for App Service](#11-demo-shell-execution--defender-for-app-service)
    - [11a. Guaranteed alert — the Microsoft-documented EICAR test URL (run this first)](#11a-guaranteed-alert--the-microsoft-documented-eicar-test-url-run-this-first)
    - [11b. Narrative trigger — the `/debug/exec` endpoint](#11b-narrative-trigger--the-debugexec-endpoint)
  - [12. Demo: DevOps findings — Defender for DevOps / GHAS](#12-demo-devops-findings--defender-for-devops--ghas)
    - [12a. GHAS / Code Scanning prerequisites](#12a-ghas--code-scanning-prerequisites)
    - [12b. Transferring the repo to a GHAS-enabled organization](#12b-transferring-the-repo-to-a-ghas-enabled-organization)
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

```powershell
# Azure CLI (Windows)
winget install Microsoft.AzureCLI

# .NET 10 SDK
winget install Microsoft.DotNet.SDK.10
```

Log in to Azure:

```powershell
az login
az account set --subscription "<your subscription name or ID>"
```

---

## 2. One-time Azure setup

### 2a. Create the resource group

```powershell
az group create `
  --name rg-umbrella-demo `
  --location westeurope
```

### 2b. Create a service principal and configure OIDC for GitHub Actions

Create the service principal:

```powershell
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

```powershell
az ad signed-in-user show --query id -o tsv
```

Save this value; you will use it as `KV_ADMIN_OBJECT_ID`.

### 2d. Create a second service principal for the Key Vault enumeration demo

This SP needs **no permissions** — its failed access is what triggers the Defender for Key Vault alert.

```powershell
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

```powershell
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

```powershell
gh secret set AZURE_CLIENT_ID
gh secret set AZURE_TENANT_ID
gh secret set AZURE_SUBSCRIPTION_ID
gh secret set SQL_ADMIN_PASSWORD
gh secret set KV_ADMIN_OBJECT_ID
gh secret set SWA_DEPLOYMENT_TOKEN   # leave blank for now; update after step 4d
```

Alternatively, populate all secrets at once from a `.env` file:

```powershell
gh secret set --env-file .env
```

### 3c. Add repository variables

Go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable name | Value |
|---|---|
| `AZURE_RG` | `rg-umbrella-demo` |
| `AZURE_WEBAPP_NAME` | `umbrella-api` (must match the `prefix` parameter in the Bicep files) |

Or use the GitHub CLI:

```powershell
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

```powershell
git checkout broken
git commit --allow-empty -m "chore: trigger broken baseline deploy"
git push
```

Or trigger the workflow directly without a commit:

```powershell
gh workflow run deploy.yml --ref broken
```

This triggers `.github/workflows/deploy.yml`, which:

1. Builds and publishes the .NET 10 app.
2. Deploys `infra/broken.bicep` to `rg-umbrella-demo`.
3. Zip-deploys the app to the App Service.
4. Deploys the frontend to Static Web Apps.

Watch progress at **GitHub → Actions**, or follow it in the terminal:

```powershell
gh run watch
```

### 4b. Confirm resources are created

```powershell
az resource list `
  --resource-group rg-umbrella-demo `
  --output table
```

You should see: App Service plan, App Service, Static Web App, SQL Server, SQL Database, Storage Account, Key Vault, and API Management.

> **APIM note:** The Developer SKU takes 30–45 minutes to provision on first deploy. The workflow will wait. Plan ahead.

### 4c. Retrieve the APIM gateway URL

```powershell
az apim show `
  --name umbrella-apim `
  --resource-group rg-umbrella-demo `
  --query gatewayUrl `
  --output tsv
```

### 4d. Get the Static Web Apps deployment token and save it

```powershell
az staticwebapp secrets list `
  --name umbrella-swa `
  --resource-group rg-umbrella-demo `
  --query "properties.apiKey" `
  --output tsv
```

Paste this value into the `SWA_DEPLOYMENT_TOKEN` GitHub secret (Settings → Secrets), then re-run the workflow (Actions → Deploy Umbrella → Re-run all jobs) so the frontend deploys with the token.

Or use the GitHub CLI:

```powershell
$SWA_TOKEN = $(az staticwebapp secrets list `
  --name umbrella-swa `
  --resource-group rg-umbrella-demo `
  --query "properties.apiKey" `
  --output tsv)

gh secret set SWA_DEPLOYMENT_TOKEN --body $SWA_TOKEN
gh run rerun --failed
```

### 4e. Confirm the app is working

```powershell
# Health check
curl https://umbrella-api-nl.azurewebsites.net/health

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
5. **Verify `Api` is actually Standard** (this plan is a frequent miss — its toggle is separate from "Databases" and starts as a 30-day Free trial):
   ```powershell
   az security pricing show --name Api --query "{name:name, tier:pricingTier}" -o table
   # If tier=Free:
   az security pricing create --name Api --tier Standard
   ```
6. Under **DevOps security**, confirm the GitHub environment from step 3d is connected. If the connector appears with `kind=null` / `env=null` (a stub from an aborted wizard), delete and recreate it.

### 5a. Confirm the APIM API is onboarded to Defender for APIs

Enabling the Defender for APIs **plan** is not enough — every API must be **onboarded** before any alerts fire.
See [Microsoft Learn — Protect your APIs with Defender for APIs](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-apis-deploy#onboard-apis).

**Check first — the API may already be onboarded:**

1. In the Azure Portal open **Defender for Cloud → Workload protections → API security**.
2. If `umbrella-apim` (or individual operations like `get-words`, `post-words`, `delete-words`, `get-health`) is listed there, **the API is already onboarded** — skip ahead.
3. Equivalent signal in **Recommendations** (filter by *defender*): per-operation findings such as *“API endpoints in Azure API Management should be authenticated”* with affected resources `get-words`, `post-words`, etc. confirm Defender for APIs is already monitoring the operations.

**Only if the API is *not* yet listed:**

1. Open **Defender for Cloud → Recommendations** and search for **Azure API Management APIs should be onboarded to Defender for APIs**.
   - If this recommendation does **not** appear in the list, there are no unhealthy resources — the API is already onboarded (the recommendation is hidden when nothing needs fixing).
2. Otherwise open it, select the `umbrella-api` API under **Unhealthy resources**, and click **Fix → Fix resources**.
3. Wait up to 50 minutes for the API to appear under **Workload protections → API security**, and ~30 minutes more for baseline traffic learning before burst alerts can fire.

> Allow 10–15 minutes after enabling plans (and 30–60 minutes after API onboarding) before running demo triggers — the monitoring agents and baseline learners need time to initialise. Defender for APIs anomaly detection benefits from **several hours to a day** of baseline traffic; a brand-new API with no history will not reliably emit burst alerts on the first try.

---

## 6. Verify the app is live

Run this checklist the morning of the demo:

```powershell
$APIM_URL = "https://umbrella-apim.azure-api.net"
$APP_URL = "https://umbrella-api-nl.azurewebsites.net"

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

**Expected alerts** (per [Microsoft Learn — Defender for Azure SQL alerts](https://learn.microsoft.com/en-us/azure/defender-for-cloud/alerts-azure-sql-db-and-warehouse)):

- **Vulnerability to SQL injection** (`SQL.DB_VULNERABILITY` / `SQL.MI_VULNERABILITY`) — fires when the application generates a faulty SQL statement that indicates susceptibility to injection.
- **Potential SQL injection** (`SQL.DB_POTENTIAL_SQLI`) — fires when an actual exploit against a known vulnerable statement appears to succeed.

For this demo the **Vulnerability to SQL injection** alert is the one you will see, because the malformed payload causes a SQL syntax error.

Alert latency: typically 10–30 minutes; the first alert on a brand-new SQL server can take up to ~60 minutes while Defender for SQL finishes initial activation. If nothing has appeared after 30 minutes, run the steps below first.

**Pre-flight checks (run once, before the demo):**

```powershell
# 1. Defender for SQL plan must be On at subscription level
az security pricing show --name SqlServers --query pricingTier -o tsv   # expect: Standard

# 2. Microsoft Defender for SQL must be enabled on the SQL *server*
az sql server advanced-threat-protection-setting show `
  --resource-group rg-umbrella-demo --name umbrella-sql --query state -o tsv   # expect: Enabled

# 3. Auditing should be on (Defender for SQL relies on the audit pipeline)
az sql server audit-policy show --resource-group rg-umbrella-demo --name umbrella-sql --query state -o tsv
```

If any check returns `Disabled` / `Free`, enable it in the portal under **SQL server → Microsoft Defender for Cloud** and wait ~10 minutes before retrying.

**Steps:**

1. Open the word-cloud submit page in the browser (share screen / project it).
2. In the word input box, type exactly:
   ```
   '; DROP TABLE Words;--
   ```
3. Click **Submit**. The frontend will display **Error: HTTP 500** — this is *expected*. The malformed query reaches the SQL server, fails to parse, and SQL returns an error. The alert fires on the failed statement.
4. Submit the payload **3–5 times in a row** — a single failed query can be ignored as noise; repeated identical anomalies are what tip the detector over the threshold.
5. Switch to the Azure Portal tab.
6. Open **Defender for Cloud → Security alerts**.
7. The `Vulnerability to SQL injection` alert appears (allow up to 30 minutes). Click it to show:
   - The offending query text.
   - The affected SQL Server resource.
   - The recommended remediation (use parameterised queries).

**Talking point:** The HTTP 500 error the audience sees is itself part of the story — it proves the malformed string reached the database. Defender detects the *pattern* of an injection attempt, not the outcome, so the alert would fire even if the statement had been syntactically valid and the table had actually been dropped. In the *fixed* version, the backend switches to parameterised EF Core queries, and the same payload is stored harmlessly as a literal word.

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
   ```powershell
   curl -o eicar.txt https://secure.eicar.org/eicar.com.txt
   ```
4. Upload the file to the container.
5. Wait ~60 seconds.
6. Open **Defender for Cloud → Security alerts**.
7. Show the `Malicious file uploaded to storage account` alert.

**Talking point:** EICAR is a harmless industry test string — it contains no malware. Defender for Storage scans every blob on ingestion using Microsoft Defender Antivirus. The public container misconfiguration (misconfig #1) is also visible in the Secure Score at this point.

---

## 9. Demo: API burst — Defender for APIs

**What it shows:** Defender for APIs detects an anomalous traffic spike and surfaces missing-authentication posture on the APIM gateway.

**Expected alert** (per [Microsoft Learn — API alert reference](https://learn.microsoft.com/en-us/azure/defender-for-cloud/alerts-reference#api-alerts)): `Suspicious population-level spike in API traffic to an API endpoint` or `Suspicious spike in API traffic from a single IP address`.

**Hard prerequisites — confirm before running the burst:**

1. Defender for APIs plan is **On** (step 5).
2. The `umbrella-api` API is **onboarded** to Defender for APIs (step 5a). Confirm at **Defender for Cloud → Workload protections → API security** — the API must be listed there.
3. At least 30 minutes of baseline traffic learning has elapsed since onboarding. Without a baseline, no anomaly can be detected.

Alert latency: 30 minutes to a few hours after the burst — Defender for APIs alerting is **not real-time**; this demo is best shown alongside a pre-recorded alert screenshot if you cannot guarantee the wait.

**Steps:**

1. Open Azure Cloud Shell (bash) in the Portal, or use a local terminal.
2. Set your APIM URL:
   ```powershell
   $APIM_URL = "https://umbrella-apim.azure-api.net"
   ```
3. Generate sustained traffic. A single 200-request burst is rarely large enough to clear the anomaly threshold — run a larger volume from multiple shells, or loop the burst several times over 5–10 minutes:
   ```powershell
   # Heavy burst — adjust upward if no alert fires within 1–2 hours.
   1..2000 | ForEach-Object { curl -s -o /dev/null "$APIM_URL/words" }
   Write-Host "Burst complete"
   ```
4. Open **Defender for Cloud → Security alerts** and wait.
5. Show the API anomaly alert. Click through to the APIM resource to show there is no rate-limiting policy and no subscription key required (misconfigs #5).

**Talking point:** In the fixed version, a rate-limit policy (30 calls / 60 s) blocks the burst before it reaches the backend, and every call requires a subscription key.

---

## 10. Demo: Key Vault enumeration — Defender for Key Vault

**What it shows:** Defender for Key Vault alerts on a failed/anomalous secret-listing attempt from an unknown principal.

**Expected alert** (per [Microsoft Learn — Key Vault alert reference](https://learn.microsoft.com/en-us/azure/defender-for-cloud/alerts-reference#azure-key-vault-alerts)): typically `Access from a suspicious IP address to a key vault` or `Denied access by an unusual user or application` (`KV_AnonymousAccess`, `KV_DenyAccess`).

Alert latency: typically 30 minutes to 2 hours — Defender for Key Vault uses behavioural baselines that need 24 hours of prior "normal" traffic to fire reliably. If the vault is brand-new, you may not see an alert from a single attempt; either pre-warm the vault with normal access the day before, or fall back to the documented **Tor-based validation** in [Microsoft Learn — Validate Azure Key Vault Threat Detection](https://learn.microsoft.com/en-us/azure/defender-for-cloud/alert-validation#validate-azure-key-vault-threat-detection).

**Find the actual vault name and tenant ID** (the broken Bicep names the vault `<prefix>-kv123`, not `<prefix>-kv`):

```powershell
$KV_NAME = $(az keyvault list --resource-group rg-umbrella-demo --query "[0].name" -o tsv)
$TENANT_ID = $(az account show --query tenantId -o tsv)
Write-Host "Vault: $KV_NAME    Tenant: $TENANT_ID"
```

**Steps:**

1. Log in as the attacker service principal created in step 2d:
   ```powershell
   az login --service-principal `
     --username "<attacker-sp-appId>" `
     --password "<attacker-sp-password>" `
     --tenant "$TENANT_ID"
   ```
2. Attempt to list secrets:
   ```powershell
   az keyvault secret list `
     --vault-name $KV_NAME `
     --output table
   ```
   The command will fail with `Caller is not authorized` — that is expected.
3. Repeat the failed call several times from different shells to strengthen the anomaly signal.
4. Log back in with your normal account:
   ```powershell
   az login
   ```
5. Open **Defender for Cloud → Security alerts**.
6. Show the Key Vault alert. Note that it captures the caller object ID, IP address, and the vault targeted.

**Talking point:** The alert fires even though the enumeration failed. Defender for Key Vault monitors the Azure audit plane, not just successful reads.

---

## 11. Demo: Shell execution — Defender for App Service

**What it shows:** Defender for App Service detects suspicious web-application activity and (in the broken baseline) a backend that will happily run arbitrary shell commands.

### 11a. Guaranteed alert — the Microsoft-documented EICAR test URL (run this first)

Microsoft publishes one official Defender for App Service trigger that is signature-matched on the request URL — see [Microsoft Learn — Test AppServices alerts](https://learn.microsoft.com/en-us/azure/defender-for-cloud/alert-validation#test-appservices-alerts).

```powershell
curl "https://umbrella-api-nl.azurewebsites.net/This_Will_Generate_ASC_Alert"
```

**Expected alert:** `Suspicious WordPress theme invocation detected` (test alert) — fires within ~1.5–4 hours.

> Run this as soon as the App Service has been deployed (and Defender for App Service has been **On** for ≥24 hours). It is the only Defender for App Service alert with a documented, guaranteed trigger.

### 11b. Narrative trigger — the `/debug/exec` endpoint

Use this to *show the misconfig* even if the alert from 11a has not arrived yet. The command output proves the backend is exploitable; whether Defender for App Service raises a runtime alert on the spawned shell on a Linux plan is best-effort and not guaranteed within demo timeframes.

> **Note:** On Linux App Service plans, Defender does NOT emit a runtime alert for every spawned process. It looks for *suspicious patterns* — pipe-to-shell from a download, base64-decode-then-exec, known miner/reverse-shell binaries, writes to `/tmp/` followed by execution. Demoing `whoami`, `ls`, or `cat /etc/passwd` will show that the endpoint *works* (response body proves arbitrary execution) but typically will not fire a Defender alert. Always run 11a first as the guaranteed signature trigger; treat 11b as the misconfig walkthrough.

1. Hit the debug endpoint:
   ```powershell
   curl "https://umbrella-api-nl.azurewebsites.net/debug/exec?cmd=whoami"
   ```
   Expected response:
   ```json
   {"stdout":"app\n","stderr":"","exitCode":0}
   ```
   If the response body is empty, confirm the `ENABLE_DEBUG_EXEC` app setting is `true`:
   ```powershell
   az webapp config appsettings list --name umbrella-api-nl --resource-group rg-umbrella-demo `
     --query "[?name=='ENABLE_DEBUG_EXEC']"
   ```
2. Try a second, more obviously suspicious command:
   ```powershell
   curl "https://umbrella-api-nl.azurewebsites.net/debug/exec?cmd=cat+/etc/passwd"
   ```
3. Open **Defender for Cloud → Security alerts**.
4. Show the alert from 11a (`Suspicious WordPress theme invocation detected`). If a runtime alert from 11b is also present, click through to see the process name, parent, and command line.

**Talking point:** The `/debug/exec` endpoint is gated on the `ENABLE_DEBUG_EXEC=true` app setting, which is set in `broken.bicep` and absent in `fixed.bicep`. The fixed slot has no `/debug/exec` route at all. The signature-based alert in 11a is what proves the *detection plane* is alive; the misconfig itself is what the audience sees in the response body.

> Do not run destructive commands (`rm -rf`, etc.) — the App Service plan is shared and you will need it for the rest of the demo.

---

## 12. Demo: DevOps findings — Defender for DevOps / GHAS

**What it shows:** Defender for DevOps surfaces Bicep IaC misconfigurations and a vulnerable NuGet package directly in the GitHub Security tab and the Defender for Cloud DevOps blade.

**No live trigger needed** — findings are already present after the first push to the `broken` branch.

### 12a. GHAS / Code Scanning prerequisites

Code Scanning **alerts** in the GitHub UI require one of the following — see [GitHub Docs — About code scanning](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning):

- The repository is **public** (Code Scanning is free), **or**
- The repository is **owned by an organization** and that organization has **GitHub Advanced Security** enabled on the repo.

If you see *“Code scanning alerts • Disabled — Advanced Security is only available for Organizations”* (as in the workspace screenshot), the repo is in a personal namespace. Either make it public, or transfer it to an organization that has GHAS:

### 12b. Transferring the repo to a GHAS-enabled organization

1. In GitHub, open **Settings → General** on the `Ba4bes/Umbrella` repo.
2. Scroll to **Danger Zone → Transfer ownership**.
3. Enter the destination organization (it must already have GHAS purchased / a license assigned), confirm by typing the repo name, and click **I understand, transfer this repository**.
4. GitHub will redirect old URLs to the new owner automatically.
5. In the *new* `<org>/Umbrella` repo, open **Settings → Code security and analysis**:
   - Enable **GitHub Advanced Security** (toggle on).
   - Enable **Code scanning → Set up → Default** (or keep the workflow-based CodeQL scan from `.github/workflows/security.yml`).
   - Enable **Dependabot alerts** and **Dependabot security updates**.
   - Enable **Secret scanning** and **Push protection**.
6. Update all `repo:Ba4bes/Umbrella:...` federated-credential subjects to `repo:<org>/Umbrella:...`:
   ```powershell
   az ad app federated-credential create --id <APP_ID> --parameters '{"name":"github-main-org","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<org>/Umbrella:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"]}'
   az ad app federated-credential create --id <APP_ID> --parameters '{"name":"github-broken-org","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<org>/Umbrella:ref:refs/heads/broken","audiences":["api://AzureADTokenExchange"]}'
   ```
7. Re-add all repository secrets and variables in the new repo (they do not migrate).
8. In **Defender for Cloud → Environment settings → DevOps**, remove the old connector and re-add the GitHub environment pointing at the new org.
9. Re-run the `security.yml` workflow on the `broken` branch — CodeQL, Dependency Review, and the Microsoft Security DevOps Bicep IaC scan will now publish SARIF into **Security → Code scanning alerts**.

**Alternative (no migration):** Make the repo public via **Settings → General → Change visibility → Make public**. CodeQL becomes free immediately. Acceptable if there are no secrets in the repo history (run `gh secret scanning` first).

**Steps:**

1. In GitHub, open the **Security** tab, then select **Code scanning** from the left sidebar.
   - Show the CodeQL finding: `Database query built from user-controlled sources` in [backend/UmbrellaApi/Program.cs](../backend/UmbrellaApi/Program.cs).

   Or via the GitHub CLI:

   ```powershell
   gh api repos/Ba4bes/Umbrella/code-scanning/alerts `
     --jq '.[] | {number,rule_id:.rule.id,severity:.rule.severity,file:.most_recent_instance.location.path}'
   ```

2. Open the **Security** tab and select **Dependabot** from the left sidebar.
   - Show the `Newtonsoft.Json 12.0.3` alert for CVE-2024-21907 (ReDoS, high severity).
   - Note the fix: upgrade to ≥ 13.0.1.

   Or via the GitHub CLI:

   ```powershell
   gh api repos/Ba4bes/Umbrella/dependabot/alerts `
     --jq '.[] | {number,package:.dependency.package.name,severity:.security_vulnerability.severity,summary:.security_advisory.summary}'
   ```

3. Open the **Security** tab, select **Code scanning** from the left sidebar, and filter by tool `MSDO` (or `Checkov`).
   - Show the IaC findings on [infra/broken.bicep](../infra/broken.bicep):
     - Public blob container access.
     - SQL firewall open to `0.0.0.0/0`.
     - App Service HTTPS not enforced.
     - No diagnostic settings.

   Or via the GitHub CLI:

   ```powershell
   gh api repos/Ba4bes/Umbrella/code-scanning/alerts -f tool_name=Checkov `
     --jq '.[] | {number,rule_id:.rule.id,file:.most_recent_instance.location.path}'
   ```

4. In the Azure Portal open **Defender for Cloud → DevOps security**.
   - Show the same findings surfaced from GitHub, with links back to the file and line number.
   - Show the CSPM integration: IaC findings are reflected in the Secure Score.

**Talking point:** These findings were detected *before* the infrastructure was deployed — shift-left security. The IaC scan runs on every push to `broken` or `main` via `.github/workflows/security.yml`.

---

## 13. Demo: CSPM — Secure Score and attack paths

**What it shows:** Defender CSPM aggregates all misconfigs into a Secure Score, raises recommendations, and (after a discovery delay) draws attack paths across resources.

**Hard prerequisites** (per [Microsoft Learn — Identify and analyze risks across your environment](https://learn.microsoft.com/en-us/azure/defender-for-cloud/concept-attack-path)):

- **Defender CSPM** plan must be **On** (the free CSPM plan does NOT include attack path analysis).
- The cloud security graph and attack path engine scan once every **24 hours**. After enabling CSPM you typically need to **wait 24–48 hours** before any attack paths appear. A `0` count in the Attack path analysis blade on day 1 (as in the workspace screenshot) is the expected state, not a misconfiguration.
- Resources must be present and registered in the inventory — confirm under **Defender for Cloud → Inventory** that `rg-umbrella-demo` resources are listed before expecting paths.

**Steps:**

1. Open **Defender for Cloud → Secure Score**.
   - Show the overall score (it will be low due to the broken baseline). Recommendations populate within ~30 minutes of deployment, so this part of the demo is reliable on day 1.
   - Click **View recommendations** to show the full list of active findings.

2. Open **Defender for Cloud → Recommendations**.
   - Filter by resource group `rg-umbrella-demo`.
   - Walk through the top recommendations expected from the broken baseline:
     - *Storage account public access should be disallowed* (misconfig #1)
     - *Public network access on Azure SQL Database should be disabled* / SQL firewall rule open to the internet (misconfig #2)
     - *Web Application should only be accessible over HTTPS* (misconfig #6)
     - *App Service should use the latest TLS version* (misconfig #6)
     - *Managed identity should be used in your Web App* (misconfig #8)
     - *Diagnostic logs in App Service should be enabled* (misconfig #7)
     - *API Management subscriptions should not be scoped to all APIs* / *APIs should be onboarded to Defender for APIs* (misconfig #5)

3. Open **Defender for Cloud → Attack path analysis** (requires **Defender CSPM** plan on, and 24–48h after deployment).
   - Realistic attack paths the engine generates against the broken baseline include variations of:
     - *Internet exposed Azure SQL server with high-severity vulnerabilities* (firewall `0.0.0.0–255.255.255.255` + SQL admin credentials in plain App Service app setting).
     - *Internet exposed Storage account with public read access* (anonymous blob access on the `assets` container).
     - *Internet exposed Web App with sensitive data in app settings* (plain-text SQL connection string + no MI).
   - Note: exact attack-path titles depend on what the cloud security graph discovers in *your* tenant; the three above are the most commonly generated against this baseline. If you see fewer paths, wait another 24 hours and refresh.

4. (Optional) Open **Defender for Cloud → Cloud security explorer** to run an interactive query — for example *“Internet-exposed Azure resources with high-severity recommendations”* — and use the results as a live alternative to a pre-rendered attack path.

**Talking point for a day-1 demo:** If Attack Path Analysis still shows `0` paths on stage, use **Recommendations** and **Cloud security explorer** as the CSPM visual. Attack paths require a full graph-scan cycle, and a deliberately newly-deployed environment will not yet have one.

---

## 14. Switching to the fixed version (live remediation)

Run this on stage to show the Secure Score improving and alerts resolving.

### Option A — push to main (full redeploy, ~10 minutes)

```powershell
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

```powershell
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

```powershell
az group delete `
  --name rg-umbrella-demo `
  --yes `
  --no-wait
```

Also clean up the AAD service principals:

```powershell
az ad sp delete --id "<sp-umbrella-github-appId>"
az ad sp delete --id "<sp-umbrella-kv-attacker-appId>"
```

---

## Quick-reference: alert timing

Latencies below match Microsoft Learn defaults; expect the upper end on a brand-new subscription where baselines are still warming up.

| Demo | Trigger action | Typical alert latency |
|---|---|---|
| SQL injection | Submit `'; DROP TABLE Words;--` in word form 3–5× (HTTP 500 is expected) | 10–30 min (up to 60 min on first activation) |
| Malware upload | Upload EICAR blob | ~60 s |
| API burst | 2 000-request loop **after** API is onboarded to Defender for APIs | 30 min – a few hours |
| Key Vault enumeration | Repeated denied `az keyvault secret list` from unprivileged SP | 30 min – 2 hours |
| App Service — guaranteed | `GET /This_Will_Generate_ASC_Alert` (MS Learn signature trigger) | 1.5–4 hours |
| App Service — narrative | `GET /debug/exec?cmd=whoami` | Best-effort, not guaranteed |
| DevOps findings | Already present after first push (requires GHAS on org repo) | Instant |
| CSPM recommendations | Already present after deployment | ~30 min |
| CSPM attack paths | Requires Defender CSPM on | **24–48 hours** |

---

## Troubleshooting

**No alerts in Defender for Cloud after running demo triggers (most common)**

Check the live state with the diagnostic commands below before blaming alert latency. The most frequent failures observed during a fresh deploy:

- **Defender for APIs is still `Free`** (30-day trial, not consumed). Even though step 5 enables the other plans, the `Api` plan is a separate toggle and is often missed. Verify and fix:
  ```powershell
  az security pricing show --name Api --query "{name:name, tier:pricingTier}" -o table
  # If tier=Free, enable it:
  az security pricing create --name Api --tier Standard
  ```
  After flipping to Standard you still need step 5a (onboard `umbrella-api`) and **~30 min** of baseline traffic before any API anomaly alert can fire.

- **APIM API not onboarded.** Confirm via REST:
  ```powershell
  $sub = az account show --query id -o tsv
  az rest --method GET --url "https://management.azure.com/subscriptions/$sub/resourceGroups/rg-umbrella-demo/providers/Microsoft.ApiManagement/service/umbrella-apim/apis/umbrella-api/providers/Microsoft.Security/apiCollections?api-version=2023-11-15"
  ```
  A `404 Not Found` means the API is NOT onboarded — follow step 5a.

- **SQL auditing is `Disabled`.** Defender for SQL ATP fires alerts on Azure SQL DB without auditing, but enabling auditing to Log Analytics makes the alert investigation usable. Check and enable:
  ```powershell
  az sql server audit-policy show -g rg-umbrella-demo -n umbrella-sql --query state -o tsv
  ```

- **Shell-exec demo (`/debug/exec`) ran with a benign command.** App Service Defender on Linux detects *suspicious process patterns*, not every `Process.Start`. `whoami` / `ls` / `cat /etc/passwd` will return data but rarely raise a runtime alert. Use the documented signature trigger from step 11a (`/This_Will_Generate_ASC_Alert`) as the guaranteed alert, and reserve `/debug/exec` for the narrative.

**Defender for DevOps GitHub connector exists but no findings appear in the DevOps blade**

First confirm the connector is actually configured (not just present as a name). The interesting fields live under `properties`:

```powershell
$sub = az account show --query id -o tsv
az rest --method GET --url "https://management.azure.com/subscriptions/$sub/providers/Microsoft.Security/securityConnectors?api-version=2024-08-01-preview" `
  --query "value[].{name:name, env:properties.environmentName, type:properties.environmentData.environmentType, offerings:properties.offerings[].offeringType}"
```

A healthy connector returns something like:
```json
{ "name": "GH-Ba4bes", "env": "Github", "type": "GithubScope", "offerings": ["CspmMonitorGithub"] }
```

If those fields are populated, the connector is **fine — do not delete it**. The usual reasons findings still don't appear:

- The connector only carries `CspmMonitorGithub`. Code-scanning / Dependabot / secret findings need the **GitHub Advanced Security** offering added — open the connector in **Defender for Cloud → Environment settings → `<connector-name>` → Settings** and enable the GHAS plan (this in turn requires GHAS on the repo, see section 12a).
- Defender for DevOps surfaces alerts from the **default branch**. Your findings live on `broken`; merge to `main` (or change the repo's default branch temporarily) before the next sync.
- The connector polls roughly **once every 24 h**. Fresh findings typically take up to a day to appear after a push.

Only recreate the connector if the `env` / `environmentType` / `hierarchyIdentifier` fields actually come back `null` — that indicates a wizard aborted before completing the GitHub App authorization.

**GitHub Security tab shows zero code-scanning alerts but the workflow runs are green**

The Code Scanning UI defaults to alerts on the **default branch** (`main` in this repo, which uses `fixed.bicep` and has no findings). Alerts on the `broken` branch exist and are accessible via:

- **GitHub UI:** open the **Security → Code scanning** page and change the **Branch** filter from `main` to `broken`.
- **GitHub CLI:**
  ```powershell
  gh api 'repos/Ba4bes/Umbrella/code-scanning/alerts?ref=refs/heads/broken&state=open&per_page=20' `
    --jq '.[] | {rule:.rule.id, sev:.rule.severity, path:.most_recent_instance.location.path, tool:.tool.name}'
  ```
  Expected on the broken branch: CodeQL `cs/sql-injection` and `cs/command-line-injection` in `backend/UmbrellaApi/Program.cs`, plus ~20 Checkov rules on `infra/broken.bicep`.

For an on-stage demo, either toggle the branch filter to `broken`, or open a PR `broken → main` so the findings land on the default branch (and `dependency-review` fires).

**`Newtonsoft.Json 12.0.3` CVE does not appear as a Dependabot alert**

Dependabot alerts default to **disabled** for newly created repos. Confirm:

```powershell
gh api repos/Ba4bes/Umbrella --jq '.security_and_analysis'
```

If `dependabot_security_updates.status` is `disabled`, enable it in **Settings → Code security → Dependabot alerts** (and **Dependabot security updates**). The Newtonsoft.Json CVE-2024-21907 alert appears within ~15 minutes after enabling. Note that the `dependency-review` job in `security.yml` is intentionally gated on `pull_request` (the action does not support `push`); to surface the CVE through that path, open a PR from `broken` to `main`.

**App Service returns 503 on startup**
- Check that `DOTNETCORE|10.0` is available in the chosen region: `az webapp list-runtimes --os linux | grep DOTNETCORE`.
- Fall back to self-contained publish if the image is not yet available: add `<SelfContained>true</SelfContained>` and `<RuntimeIdentifier>linux-x64</RuntimeIdentifier>` to the `.csproj`.

**APIM returns 401 on the broken baseline**
- Confirm `subscriptionRequired: false` is set. The APIM Developer SKU sometimes takes up to 45 minutes to fully propagate policy changes after first deploy.

**No Defender alerts appearing**
- Verify all Defender plans are **On** in Environment settings (step 5).
- Wait 10–15 minutes after enabling a plan before running the trigger.
- Check that the resource group `rg-umbrella-demo` is in scope for the plan.

**`/debug/exec` returns 404 or empty body**
- Confirm the `ENABLE_DEBUG_EXEC` app setting is `true` in the App Service configuration: `az webapp config appsettings list --name umbrella-api-nl --resource-group rg-umbrella-demo`.
- Note the App Service name in the broken Bicep is `umbrella-api-nl`, not `umbrella-api`. The default backend URL is `https://umbrella-api-nl.azurewebsites.net`.
- After changing the app setting, restart the App Service: `az webapp restart --name umbrella-api-nl --resource-group rg-umbrella-demo`.

**GitHub Actions deploy fails with OIDC / login error**
- Confirm `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` secrets are set correctly.
- Verify that a federated credential exists for the exact branch being pushed to (check with `az ad app federated-credential list --id <APP_ID>`).
- Ensure the workflow job has `permissions: id-token: write` — this is required for OIDC token issuance.
