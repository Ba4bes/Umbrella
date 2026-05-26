# Original Discovery Request — rg-umbrella-demo

## Source Scope

| Field | Value |
|---|---|
| Type | Resource group |
| Name | `rg-umbrella-demo` |
| Subscription | `9bd9cf0b-dfc1-4fd3-833c-9fdf4d49d9d2` (Azure subscription 1) |
| Location | `westeurope` |
| Discovery date | 2026-05-26 |
| Skill | `azv-azure-to-diagram` |

## Counts

| Metric | Count |
|---|---|
| Total resources discovered | 10 |
| Excluded (system/auto-created) | 1 |
| Diagram-worthy resources | 9 |
| Inferred relationships | 8 |
| Diagram pages | 1 (Architecture Overview) |

## Resource Table (diagram-worthy)

| # | Name | Type | Location |
|---|---|---|---|
| 1 | umbrellast | Microsoft.Storage/storageAccounts | westeurope |
| 2 | umbrella-swa | Microsoft.Web/staticSites | westeurope |
| 3 | umbrella-apim | Microsoft.ApiManagement/service | westeurope |
| 4 | umbrella-plan | Microsoft.Web/serverFarms | westeurope |
| 5 | umbrella-kv123 | Microsoft.KeyVault/vaults | westeurope |
| 6 | umbrella-sql | Microsoft.Sql/servers | westeurope |
| 7 | umbrella-sql/UmbrellaDb | Microsoft.Sql/servers/databases | westeurope |
| 8 | umbrella-api-nl | Microsoft.Web/sites | westeurope |
| 9 | umbrellast-0111bf11-b709-4c0b-b238-41faa1afe1ad | Microsoft.EventGrid/systemTopics | westeurope |

## Excluded Resources

| Name | Type | Reason |
|---|---|---|
| umbrella-sql/master | Microsoft.Sql/servers/databases | Auto-created system database (not architecturally meaningful) |

## Relationships

| # | Source | Relationship | Target | Evidence |
|---|---|---|---|---|
| 1 | umbrella-api-nl | depends | umbrella-plan | App Service `serverFarmId` references the plan |
| 2 | umbrella-api-nl | connects | umbrella-sql | App setting `SqlConnectionString` references `umbrella-sql.database.windows.net` |
| 3 | umbrella-sql | contains | umbrella-sql/UmbrellaDb | Parent/child ARM relationship |
| 4 | umbrellast-eventgrid-sys-topic | depends | umbrellast | EventGrid `source` references the storage account |
| 5 | umbrella-swa | connects | umbrella-apim | (inferred) Co-located SPA → APIM front-door — RG ≤15 resources |
| 6 | umbrella-apim | connects | umbrella-api-nl | (inferred) APIM → backend App Service in same RG |
| 7 | umbrella-api-nl | connects | umbrella-kv123 | (inferred) Co-located Key Vault, no explicit `@Microsoft.KeyVault` references found |
| 8 | umbrella-api-nl | connects | umbrellast | (inferred) Co-located Storage Account, no explicit connection string |

## Enrichment Notes

- `umbrella-api-nl` (App Service) — no managed identity assigned; no named connection strings; one app setting (`SqlConnectionString`) points at `umbrella-sql`.
- `umbrella-kv123` — access policy grants object `5df3e100-b316-4b85-9f01-0cb40e568371` (tenant `b9feaee7-c137-48f2-9423-2531591c48b4`) read/write secret permissions. No private endpoint or `networkAcls` restrictions.
- `umbrella-sql` — `publicNetworkAccess` is `Enabled`; no Azure AD admin configured; no private endpoint.
- `umbrella-swa` — Free SKU, linked to GitHub repository `Ba4bes/Umbrella`, branch `broken`. No custom domains. No database connections registered.

## Security Observations

The following items were noted during enrichment but are **not** rendered as relationships — they may warrant follow-up:

- `umbrella-api-nl` exposes a SQL Server connection string with a literal password in plain-text app settings (`SqlConnectionString` / value contains `Password=...`). Consider moving to a Key Vault reference and granting the App Service a managed identity.
- `umbrella-api-nl` has `ENABLE_DEBUG_EXEC=true` set in app settings.
- `umbrella-sql` allows `publicNetworkAccess = Enabled` without a configured Azure AD admin.

## Next Steps

- Compare this diagram against a Bicep template → run the `azv-bicep-diagram-sync` skill.
- Generate Bicep + deployment scripts from this diagram → run the `azv-diagram-to-bicep` skill.
- Detect drift between this diagram and live Azure → run the `azv-diagram-azure-sync` skill.
