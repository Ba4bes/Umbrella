# Umbrella — Revised Plan (App Service + .NET 10)

Replace Container Apps with Azure App Service (Linux, code deploy) and rebuild the backend as an ASP.NET Core 10 Web API. Frontend (Static Web Apps + wordcloud2.js), APIM, SQL DB, Blob, Key Vault, and the overall Defender for Cloud demo flow stay the same. The Defender for Containers demo is replaced with a Defender for App Service runtime alert plus a Defender for DevOps (GHAS) scan on the .NET project.

## Architecture

| Component | Azure service | Defender plan | What you demonstrate |
|---|---|---|---|
| Frontend | Static Web Apps | Defender for App Service | Suspicious scanner traffic, command injection attempts in query params |
| API gateway | API Management | Defender for APIs | Burst traffic, shadow API calls, missing auth |
| Backend | **App Service (Linux, .NET 10)** | **Defender for App Service** | Runtime anomaly alerts (suspicious process, web shell upload, dangerous PowerShell-like behavior) |
| Word store | SQL Database | Defender for Databases | SQL injection detection, anomalous query patterns |
| Assets | Blob Storage | Defender for Storage | EICAR malware upload, public container, sensitive data discovery |
| Secrets | Key Vault | Defender for Key Vault | Unusual access pattern, secret enumeration |
| CI/CD | GitHub Actions | **Defender for DevOps (GHAS)** | IaC scan of Bicep + dependency scan of .NET project (replaces container CVE story) |
| Everything | All resources | Defender CSPM | Secure Score, attack paths, compliance, misconfig recommendations |

## Backend stack

- **ASP.NET Core 10 Minimal API** targeting `net10.0`.
- Endpoints: `POST /words`, `GET /words`, `GET /health`.
- EF Core 10 with `Microsoft.Data.SqlClient` for the SQL DB.
- "Broken" version uses string-concatenated SQL (for the injection demo); "fixed" version uses parameterized queries / EF parameters.
- Configuration via `IConfiguration`; broken version reads the SQL connection string from an App Service app setting, fixed version uses a Key Vault reference (`@Microsoft.KeyVault(...)`) bound through Managed Identity.
- Deployment: `dotnet publish` → zip deploy via `Azure/webapps-deploy@v3` (no container image).
- App Service: Linux plan (B1 or P1v3), runtime stack `DOTNETCORE|10.0`, HTTPS-only toggled off in broken version.

## Intentional misconfigs (broken baseline)

1. Blob container with public access enabled.
2. SQL firewall `0.0.0.0`–`255.255.255.255` + "Allow Azure services" on.
3. SQL connection string stored directly as an App Service app setting (not a Key Vault reference).
4. **Outdated, vulnerable NuGet packages pinned** (e.g., a known-CVE version of `Newtonsoft.Json` or `System.Data.SqlClient`) so Defender for DevOps / Dependabot lights up — replaces the `node:18` story.
5. APIM without rate limiting and no subscription key required.
6. HTTPS-only **disabled** and minimum TLS set to 1.0 on the App Service.
7. No diagnostic settings routed to Log Analytics.
8. **System-assigned Managed Identity disabled** on the App Service (forces secret-based auth path); fixed version enables MI + Key Vault references.

## Demo trigger scenarios

- **SQL injection**: submit `'; DROP TABLE Words;--` as a word. Defender for Databases alert.
- **Malware upload**: upload EICAR to the blob container via the Portal. Defender for Storage alert (~60s).
- **API burst**: `for i in $(seq 1 200); do curl -s -o /dev/null https://<apim>.azure-api.net/words; done`. Defender for APIs anomaly.
- **Key Vault enumeration**: second SP with no perms runs `az keyvault secret list`. Defender for Key Vault alert.
- **App Service runtime alert** *(new, replaces container CVE)*: hit a deliberately exposed diagnostic endpoint that shells out, e.g. `GET /debug/exec?cmd=whoami` in the broken build, to trigger Defender for App Service "suspicious process execution" / "command-line attack" detection.
- **Defender for DevOps**: open the security tab in GitHub / Defender for Cloud DevOps blade to show the Bicep IaC findings and the vulnerable-NuGet finding from the .NET project.

## Build scope

- **Frontend**: static SPA using `wordcloud2.js`, polling backend every 3s. Hosted on Static Web Apps. Unchanged from prior plan.
- **Backend**: ASP.NET Core 10 minimal API (~150 lines) with the three endpoints above, plus the intentional `/debug/exec` endpoint in the broken build only.
- **Infrastructure**: two Bicep files (`broken.bicep`, `fixed.bicep`) provisioning RG, App Service plan + App Service, Static Web App, APIM, SQL Server + DB, Storage Account + container, Key Vault, Log Analytics (in fixed only).
- **CI/CD**: GitHub Actions workflow building/publishing the .NET app, deploying Bicep, and running CodeQL + dependency review for the Defender for DevOps story.

## Out of scope

- Containers / Docker / Container Apps / ACR.
- WebSockets / SignalR (3s polling is sufficient).
- Authentication on the frontend (anonymous submissions by design).

## Open questions (recommendations)

1. **App Service SKU** — B1 (cheap, demo-friendly) vs P1v3 (needed for VNet integration if you later want private endpoints). *Recommend B1 for the talk.*
2. **Single backend or split broken/fixed slots?** — Deployment slots let you flip live on stage. *Recommend two slots on the same App Service.*
3. **.NET 10 GA timing** — confirm the App Service Linux image has `DOTNETCORE|10.0` available in your demo region; otherwise fall back to self-contained publish.
