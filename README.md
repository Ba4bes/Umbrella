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
