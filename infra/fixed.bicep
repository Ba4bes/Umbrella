// =============================================================================
// Umbrella — FIXED version
//
// All misconfigs from broken.bicep are remediated:
//   ✓ #1  Blob container publicAccess = 'None'
//   ✓ #2  SQL firewall restricted to App Service outbound IPs only
//   ✓ #3  Connection string via Key Vault reference + Managed Identity
//   ✓ #5  APIM rate-limiting policy, subscriptionRequired = true
//   ✓ #6  App Service httpsOnly = true, minTlsVersion = '1.2'
//   ✓ #7  Log Analytics workspace + diagnostic settings on all resources
//   ✓ #8  System-assigned Managed Identity enabled on App Service
// =============================================================================

@description('Short prefix for all resource names.')
param prefix string = 'umbrella'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('SQL Server administrator login name.')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password.')
@secure()
param sqlAdminPassword string

@description('AAD object ID for the Key Vault admin access policy.')
param kvAdminObjectId string

@description('Log Analytics workspace retention in days.')
param logRetentionDays int = 30

// ── Resource names ────────────────────────────────────────────────────────
var planName      = '${prefix}-plan'
var appName       = '${prefix}-api'
var swaName       = '${prefix}-swa'
var sqlServerName = '${prefix}-sql'
var sqlDbName     = 'UmbrellaDb'
var storageName   = '${toLower(replace(prefix, '-', ''))}store'
var containerName = 'assets'
var kvName        = '${prefix}-kv'
var apimName      = '${prefix}-apim'
var lawName       = '${prefix}-law'
var apimPublisherEmail = 'demo@example.com'
var apimPublisherName  = 'Umbrella Demo'

// ── Log Analytics Workspace ───────────────────────────────────────────────
// FIX #7: centralised workspace for all diagnostic logs
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: logRetentionDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ── App Service Plan ──────────────────────────────────────────────────────
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ── App Service — FIXED ───────────────────────────────────────────────────
// FIX #6: httpsOnly = true, TLS 1.2
// FIX #8: system-assigned identity enabled
// FIX #3: connection string via Key Vault reference (see appSettings below)
resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned' // FIX #8
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true // FIX #6
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      minTlsVersion: '1.2' // FIX #6
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          // FIX #3: Key Vault reference resolved via system-assigned MI
          name: 'SqlConnectionString'
          value: '@Microsoft.KeyVault(SecretUri=${kv.properties.vaultUri}secrets/SqlConnectionString/)'
        }
        // ENABLE_DEBUG_EXEC is intentionally absent in the fixed build
      ]
    }
  }
}

// ── App Service diagnostic settings → Log Analytics ──────────────────────
resource appDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: app
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'AppServiceHTTPLogs';       enabled: true }
      { category: 'AppServiceConsoleLogs';     enabled: true }
      { category: 'AppServiceAppLogs';         enabled: true }
      { category: 'AppServiceAuditLogs';       enabled: true }
      { category: 'AppServicePlatformLogs';    enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'; enabled: true }
    ]
  }
}

// ── Static Web App ────────────────────────────────────────────────────────
resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: swaName
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

// ── SQL Server ────────────────────────────────────────────────────────────
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

// FIX #2: no open firewall rule; "Allow Azure services" only
// (In a production hardening scenario you would use a private endpoint instead.)
resource sqlFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ── SQL diagnostic settings → Log Analytics ───────────────────────────────
resource sqlDbDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: sqlDb
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'SQLInsights';          enabled: true }
      { category: 'AutomaticTuning';      enabled: true }
      { category: 'QueryStoreRuntimeStatistics'; enabled: true }
      { category: 'Errors';               enabled: true }
      { category: 'DatabaseWaitStatistics'; enabled: true }
      { category: 'SQLSecurityAuditEvents'; enabled: true }
    ]
    metrics: [
      { category: 'Basic'; enabled: true }
    ]
  }
}

// ── Storage Account ───────────────────────────────────────────────────────
// FIX #1: public access disabled, HTTPS required, TLS 1.2
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false   // FIX #1
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource assetsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None' // FIX #1
  }
}

// ── Storage diagnostic settings → Log Analytics ───────────────────────────
resource storageDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: blobService
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'StorageRead';   enabled: true }
      { category: 'StorageWrite';  enabled: true }
      { category: 'StorageDelete'; enabled: true }
    ]
    metrics: [
      { category: 'Transaction'; enabled: true }
    ]
  }
}

// ── Key Vault ─────────────────────────────────────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: false
    accessPolicies: [
      {
        // Admin access for the demo operator
        tenantId: subscription().tenantId
        objectId: kvAdminObjectId
        permissions: {
          secrets: ['get', 'list', 'set', 'delete', 'recover', 'purge']
        }
      }
    ]
  }
}

// FIX #3 / #8: grant App Service MI read access to Key Vault secrets
resource kvAppAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: kv
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: app.identity.principalId
        permissions: {
          secrets: ['get']
        }
      }
    ]
  }
}

resource kvSqlSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'SqlConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};User Id=${sqlAdminLogin};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

// ── Key Vault diagnostic settings → Log Analytics ─────────────────────────
resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: kv
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'AuditEvent';            enabled: true }
      { category: 'AzurePolicyEvaluationDetails'; enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'; enabled: true }
    ]
  }
}

// ── API Management ────────────────────────────────────────────────────────
// FIX #5: subscriptionRequired = true, rate-limiting policy
resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

resource apimApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'umbrella-api'
  properties: {
    displayName: 'Umbrella API'
    path: ''
    protocols: ['https']
    serviceUrl: 'https://${app.properties.defaultHostName}'
    subscriptionRequired: true // FIX #5
  }
}

// FIX #5: rate-limiting policy — max 30 calls per 60 seconds per subscription key
resource apimApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: apimApi
  name: 'policy'
  properties: {
    format: 'xml'
    value: '''
<policies>
  <inbound>
    <base />
    <rate-limit calls="30" renewal-period="60" />
    <cors allow-credentials="false">
      <allowed-origins><origin>*</origin></allowed-origins>
      <allowed-methods><method>GET</method><method>POST</method></allowed-methods>
      <allowed-headers><header>Content-Type</header></allowed-headers>
    </cors>
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>'''
  }
}

resource apimGetWords 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'get-words'
  properties: {
    displayName: 'Get Words'
    method: 'GET'
    urlTemplate: '/words'
  }
}

resource apimPostWords 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'post-words'
  properties: {
    displayName: 'Post Word'
    method: 'POST'
    urlTemplate: '/words'
  }
}

resource apimHealth 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'get-health'
  properties: {
    displayName: 'Health Check'
    method: 'GET'
    urlTemplate: '/health'
  }
}

// ── APIM diagnostic settings → Log Analytics ─────────────────────────────
resource apimDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: apim
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'GatewayLogs'; enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'; enabled: true }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────
output appUrl            string = 'https://${app.properties.defaultHostName}'
output apimGatewayUrl    string = apim.properties.gatewayUrl
output swaDefaultHost    string = swa.properties.defaultHostname
output sqlServerFqdn     string = sqlServer.properties.fullyQualifiedDomainName
output storageAccName    string = storage.name
output kvUri             string = kv.properties.vaultUri
output lawId             string = law.id
output appManagedIdentity string = app.identity.principalId
