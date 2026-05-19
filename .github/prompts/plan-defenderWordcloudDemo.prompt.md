# Plan: Umbrella — Defender for Cloud Wordcloud Demo — Phased Build

Build **Umbrella**, a deliberately-vulnerable wordcloud web app spanning 7 Azure services so each Microsoft Defender for Cloud plan can be demonstrated live during a conference talk. Ship a "broken" baseline first (low Secure Score, multiple misconfigs), then enable Defender plans and remediate on stage. Eighth feature: Defender for DevOps via GitHub Actions scanning Bicep + container image.

## Phase 1 — App scaffolding (local only)
1. Create repo layout: `frontend/`, `backend/`, `infra/`, `.github/workflows/`.
2. Backend (`backend/`): Node.js + Express, Dockerfile based on `node:18` (intentionally unpatched). Endpoints `POST /words`, `GET /words`, `GET /health`. Two DB modes selected by env var: vulnerable (string-concatenated SQL) for baseline, parameterized for the "fixed" branch.
3. Frontend (`frontend/`): static SPA with landing-page single-question poll → word submission view rendered with `wordcloud2.js`, polling `GET /words` every 3s.
4. Verification: `docker compose up` runs frontend + backend + local SQL; submit words, see cloud grow; EICAR string accepted as a "word" payload locally.

## Phase 2 — Broken-baseline IaC
1. Author `infra/main.broken.bicep` provisioning: Static Web App, APIM (no rate-limit, no subscription key), Container App + ACR, Azure SQL, Storage account + blob container (public access), Key Vault, Log Analytics (not wired to resources).
2. Bake in the 7 intentional misconfigs from plan.md (public blob, wide SQL firewall, plaintext connstring env var, `node:18`, open APIM, HTTPS-only off, no diagnostic settings).
3. Author `infra/main.fixed.bicep` as the remediated counterpart (Key Vault references, private endpoints where reasonable, parameterized image tag, rate-limit policy, diagnostic settings → Log Analytics). Keep in source control for the "before/after" diff.
4. Verification: `az deployment group what-if` succeeds on both files; broken deployment surfaces expected misconfig recommendations once Defender CSPM is on.

## Phase 3 — Deploy broken baseline
1. Create resource group; deploy `main.broken.bicep`.
2. Build & push backend image to ACR with `node:18` base.
3. Wire Container App → SQL (plaintext connstring), APIM → Container App, Static Web App → APIM.
4. Smoke test end-to-end: submit a word from the SPA, confirm it appears in the cloud.
5. Verification: app works; Secure Score deliberately low; resources visible in portal.

## Phase 4 — Enable Defender plans
1. Enable per-plan in the subscription: App Service, APIs, Containers, Databases (SQL), Storage (with malware scanning + sensitive data discovery), Key Vault, CSPM (Standard tier for attack paths).
2. Trigger initial container image scan by re-pushing image; confirm CVE findings on `node:18`.
3. Verification: each plan shows "On" in Defender for Cloud > Environment settings; recommendations populated.

## Phase 5 — Demo trigger scenarios (rehearse)
Run each at least once end-to-end and capture timing notes:
1. SQL injection: submit `'; DROP TABLE Words;--` → Defender for Databases alert.
2. Malware: upload EICAR to blob via portal → Defender for Storage alert (~60s).
3. API burst: 200x curl loop from Cloud Shell → Defender for APIs anomaly.
4. Key Vault enumeration: unprivileged SP runs `az keyvault secret list` → Defender for Key Vault alert.
5. Container CVE: navigate to Workload protections → show findings (no trigger needed).
- Verification: every alert observed within 1–3 min; screenshots/recordings saved as fallback.

## Phase 6 — Defender for DevOps (GitHub)
1. Connect the repo to Defender for Cloud (DevOps connector).
2. Add `.github/workflows/security.yml`: Microsoft Security DevOps action scanning Bicep (IaC) + container image build.
3. Confirm IaC scan flags the 7 intentional misconfigs in `main.broken.bicep` before deploy.
4. Verification: PR check fails on broken Bicep, passes on fixed Bicep; findings visible in Defender for Cloud > DevOps security.

## Phase 7 — Demo polish
1. Reset script: redeploys broken baseline, clears Words table, deletes EICAR blob, resets Key Vault access policies. One command from Cloud Shell.
2. Click-through map: a one-page diagram (in `README.md`) where each service links to the matching Defender plan section — supports the "click any box to ask follow-ups" framing.
3. Two pre-built wordcloud prompts queued: opener ("what do you know about Defender?") and closer ("what will you implement?").
4. Verification: end-to-end dry run on the conference network profile; reset script returns env to baseline in <5 min.

## Relevant files (to be created)
- `backend/` — Express app, Dockerfile, `db.js` with vulnerable + parameterized modes
- `frontend/` — static SPA, `wordcloud2.js` integration, polling client
- `infra/main.broken.bicep`, `infra/main.fixed.bicep` — paired IaC
- `.github/workflows/security.yml` — MSDO scan
- `scripts/reset-demo.sh` — Phase 7 reset
- `README.md` — architecture diagram + Defender mapping table from plan.md

## Decisions
- Wordcloud over poll (per plan.md).
- Polling (3s) over WebSockets — simpler, conference-network friendly.
- Node.js/Express backend, ~150 LOC target — keep app trivial; the *infra* is the demo.
- Keep broken + fixed Bicep both in `main` branch for diffable before/after.
- Out of scope: production hardening beyond `main.fixed.bicep`, custom domain/TLS, auth on the SPA.

## Further considerations
1. Where to host the static frontend during the burst-traffic demo? Recommend: Static Web Apps free tier (matches "Defender for App Service" row). Alternative: App Service if you want richer App Service-specific alerts.
2. Single subscription vs. dedicated demo subscription? Recommend dedicated — Defender plan billing is per-resource/hour and alerts won't be polluted by other workloads.
3. Rehearsal env identical to live env, or shared? Recommend identical-but-separate RG so reset script is destructive-safe.
