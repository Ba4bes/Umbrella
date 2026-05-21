# Umbrella

A **Defender for Cloud** demo built around a live word-cloud app. Attendees submit words; the cloud grows in real time. The infrastructure is intentionally misconfigured in the "broken" baseline so every major Defender plan has something to fire on.

## Architecture

| Component | Azure service | Defender plan | What you demonstrate |
|---|---|---|---|
| Frontend | Static Web Apps | Defender for App Service | Suspicious scanner traffic, command injection in query params |
| API gateway | API Management | Defender for APIs | Burst traffic, shadow API calls, missing auth |
| Backend | **App Service (Linux, .NET 10)** | **Defender for App Service** | Runtime anomaly: suspicious process execution via `/debug/exec` |
| Word store | SQL Database | Defender for Databases | SQL injection detection, anomalous query patterns |
| Assets | Blob Storage | Defender for Storage | EICAR malware upload, public container, sensitive data |
| Secrets | Key Vault | Defender for Key Vault | Unusual access, secret enumeration |
| CI/CD | GitHub Actions | **Defender for DevOps (GHAS)** | Bicep IaC scan + vulnerable NuGet package (Dependabot) |
| Everything | All resources | Defender CSPM | Secure Score, attack paths, compliance |

## Repository layout

```
├── frontend/                  # wordcloud2.js SPA → Azure Static Web Apps
├── backend/UmbrellaApi/       # ASP.NET Core 10 Minimal API
├── infra/
│   ├── broken.bicep           # Intentionally misconfigured baseline
│   └── fixed.bicep            # Remediated version
└── .github/workflows/
    ├── deploy.yml             # Build → Bicep deploy → App Service zip deploy
    └── security.yml           # CodeQL + Dependency Review + Bicep IaC scan
```

## Broken baseline misconfigs

1. Blob container with **public access** enabled
2. SQL firewall rule `0.0.0.0`–`255.255.255.255`
3. SQL connection string stored as a **plain App Service app setting**
4. **Outdated NuGet packages** — `Newtonsoft.Json 12.0.3` (CVE-2024-21907) triggers Dependabot
5. APIM with **no rate limiting** and no subscription key
6. App Service **HTTPS-only disabled**, minimum TLS `1.0`
7. **No diagnostic settings** routed to Log Analytics
8. **System-assigned Managed Identity disabled** (forces secret-based auth)

## Demo triggers

| Demo | How to trigger |
|---|---|
| SQL injection | Submit `'; DROP TABLE Words;--` as a word |
| Malware upload | Upload EICAR to the blob container via Portal |
| API burst | `for i in $(seq 1 200); do curl -s https://<apim>.azure-api.net/words; done` |
| Key Vault enumeration | Second SP with no perms runs `az keyvault secret list` |
| App Service runtime alert | `GET https://<app>.azurewebsites.net/debug/exec?cmd=whoami` |
| DevOps findings | GitHub / Defender for Cloud → DevOps blade → IaC + dependency findings |

## Required GitHub secrets / variables

| Secret / Variable | Purpose |
|---|---|
| `AZURE_CREDENTIALS` | Service principal JSON for `azure/login` |
| `SQL_ADMIN_PASSWORD` | SQL Server admin password |
| `KV_ADMIN_OBJECT_ID` | Object ID for Key Vault admin access policy |
| `SWA_DEPLOYMENT_TOKEN` | Static Web Apps deployment token |
| `vars.AZURE_WEBAPP_NAME` | App Service name |
| `vars.AZURE_RG` | Target resource group name |

## Switching broken ↔ fixed

- Branch `broken` → deploys `infra/broken.bicep` (misconfigs on, `/debug/exec` enabled)
- Branch `main` → deploys `infra/fixed.bicep` (all remediations applied)

Use **deployment slots** on the same App Service to flip live during the demo.

## Deployed URLs

All resource names are built from the `prefix` Bicep parameter (default: `umbrella`). Substitute your prefix if you deployed with a custom value.

| Resource | URL |
|---|---|
| Frontend (SWA display page) | `https://umbrella-swa.azurestaticapps.net` |
| Audience submit page | `https://umbrella-swa.azurestaticapps.net/submit` |
| API gateway (APIM) | `https://umbrella-apim.azure-api.net` |
| Backend direct (App Service) | `https://umbrella-api-nl.azurewebsites.net` |
| Health check | `https://umbrella-apim.azure-api.net/health` |

> **Note:** The SWA hostname is auto-generated (`<hash>.azurestaticapps.net`). Find the real URL in the Azure Portal → Static Web Apps → `umbrella-swa` → **URL**.

## Resetting the word cloud

Between demo runs, clear all submitted words with:

```bash
curl -X DELETE https://umbrella-apim.azure-api.net/words
```

The display page picks up the empty state within 3 seconds (next poll).

**Manual fallback** via Azure Portal → SQL databases → `UmbrellaDb` → Query editor:

```sql
DELETE FROM Words;
```

## Post-deployment checklist

Run these after `deploy.yml` completes to confirm everything is wired up.

```bash
APIM=https://umbrella-apim.azure-api.net

# 1. Health
curl "$APIM/health"
# Expected: {"status":"healthy", ...}

# 2. Submit a word
curl -X POST "$APIM/words" -H "Content-Type: application/json" -d '{"word":"test"}'
# Expected: {"message":"Word recorded."}

# 3. Verify it appears
curl "$APIM/words"
# Expected: [{"text":"test","count":1}]

# 4. Reset
curl -X DELETE "$APIM/words"
# Expected: {"message":"Word cloud reset."}

# 5. Confirm empty
curl "$APIM/words"
# Expected: []
```

Then open the frontend URLs in a browser:

- **Display page** → word cloud canvas and QR code are visible
- **Submit page** (`/submit`) → word input form works; submitted word appears on the display page within 3 seconds

**Broken-baseline only:**

```bash
# 6. Debug exec (triggers Defender for App Service alert)
curl "https://umbrella-api-nl.azurewebsites.net/debug/exec?cmd=whoami"

# 7. SQL injection (triggers Defender for Databases alert)
curl -X POST "$APIM/words" -H "Content-Type: application/json" \
  -d "{'word':"'; DROP TABLE Words;--"}"
```
