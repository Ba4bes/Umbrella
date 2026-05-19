Go with the wordcloud. It's more alive than a poll: the cloud grows in real time as attendees submit, it creates a natural visual payoff on your screen, and you can use it twice ("what do you know about Defender?" at the start, "what will you implement?" at the end). You can embed a single-question poll as a landing page step before the word submission, so you still get that option without needing a separate app.

Here is the architectural design, optimised specifically for Defender for Cloud demo coverage.Click any service box to ask follow-up questions about that specific Defender plan.

---

## Component-to-Defender mapping

| Component | Azure service | Defender plan | What you demonstrate |
|---|---|---|---|
| Frontend | Static Web Apps | Defender for App Service | Suspicious scanner traffic, command injection attempts in query params |
| API gateway | API Management | Defender for APIs | API anomaly alerts (burst traffic, shadow API calls, missing auth) |
| Backend | Container Apps | Defender for Containers | CVE scan on the container image, runtime anomaly detection |
| Word store | SQL Database | Defender for Databases | SQL injection detection, anomalous query patterns |
| Assets | Blob Storage | Defender for Storage | Malware upload scan (EICAR), public container misconfiguration, sensitive data discovery |
| Secrets | Key Vault | Defender for Key Vault | Unusual access pattern, secret enumeration from unknown principal |
| Everything | All resources | Defender CSPM | Secure Score, attack path analysis, regulatory compliance, misconfiguration recommendations |

**Bonus: Defender for DevOps.** Connect your GitHub repository to Defender for Cloud. A GitHub Actions workflow that scans the Bicep template and the container image gives you an eighth Defender feature to show, completely free of extra infrastructure. The IaC scan will flag the intentional misconfigs (see below) before they even deploy, which is a great "shift left" story.

---

## Intentional misconfigs to deploy first

These make your Secure Score deliberately low at the start and give the audience something to watch you fix:

1. Blob container with public access enabled (shows up in CSPM and triggers a Secure Score deduction)
2. SQL firewall rule `0.0.0.0` to `255.255.255.255` plus "Allow Azure services" checked
3. Connection string stored directly in the Container App environment variable instead of a Key Vault reference
4. Base image: `node:18` (unpatched, multiple CVEs visible in the container image scan)
5. APIM without a rate-limiting policy and no subscription key required
6. HTTPS-only not enforced on the web app
7. No diagnostic settings routing to Log Analytics (means alerts are slow or silent)

Deploy this "broken" version first as your baseline. Enable the Defender for Cloud plans live during the demo, or show the Secure Score jumping as you fix items one by one.

---

## Demo trigger scenarios (live alerts)

These all fire within 1-3 minutes of execution, which is conference-safe timing:

**SQL injection** via the word submission form: submit the string `'; DROP TABLE Words;--` as your "word". Defender for Databases raises a threat detection alert. No actual damage because you parameterise queries in the fixed version, but the alert fires regardless.

**Malware upload** to Blob Storage: upload the EICAR test file (`X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*`) to the blob container via the Azure Portal. Defender for Storage raises a malware detection alert within about 60 seconds. This is completely safe, EICAR is an industry standard test string.

**API burst** to trigger Defender for APIs anomaly: from Azure Cloud Shell, run `for i in $(seq 1 200); do curl -s -o /dev/null https://<your-apim>.azure-api.net/words; done`. The burst pattern triggers an anomaly alert in Defender for APIs.

**Key Vault enumeration**: create a second service principal, give it no permissions, then attempt to list secrets via `az keyvault secret list --vault-name <name>`. The failed access from an unusual principal triggers a Defender for Key Vault alert.

**Container CVE scan**: simply navigate to Defender for Cloud > Workload protections > Containers and show the vulnerability findings on the `node:18` image you deployed. No triggering needed, it scans on push.

---

## Build scope

The app itself is intentionally minimal. Frontend: any static SPA using `wordcloud2.js` or D3 wordcloud, polling the backend every 3 seconds (no need for WebSockets unless you want real-time push). Backend: a Node.js Express API in a Dockerfile with three endpoints: `POST /words`, `GET /words`, and `GET /health`. The entire app is maybe 150 lines of code. Infrastructure: two Bicep files, one "broken" and one "fixed", so you can show the before and after in source control.
