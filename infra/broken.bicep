// =============================================================================
// Umbrella — BROKEN baseline
//
// Intentional misconfigs (numbered to match README):
//   #1  Blob container publicAccess = 'Blob'
//   #2  SQL firewall 0.0.0.0–255.255.255.255
//   #3  Connection string as plain App Service app setting
//   #5  APIM no rate limiting, subscriptionRequired = false
//   #6  App Service httpsOnly = false, minTlsVersion = '1.0'
//   #7  No Log Analytics workspace / no diagnostic settings
//   #8  App Service system-assigned identity disabled
//
// DO NOT deploy this template to a production subscription.
// =============================================================================

@description('Short prefix for all resource names (lowercase, no hyphens).')
param prefix string = 'umbrella'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('SQL Server administrator login name.')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password.')
@secure()
param sqlAdminPassword string

@description('AAD object ID for the Key Vault access policy (admin user/group). Must be a GUID, e.g. from: az ad signed-in-user show --query id -o tsv')
@minLength(36)
@maxLength(36)
param kvAdminObjectId string

@description('Azure region for SQL Server (override if the resource group region does not accept new SQL servers).')
param sqlLocation string = 'swedencentral'

// ── Resource names ────────────────────────────────────────────────────────
var planName      = '${prefix}-plan'
var appName       = '${prefix}-api'
var swaName       = '${prefix}-swa'
var sqlServerName = '${prefix}-sql'
var sqlDbName     = 'UmbrellaDb'
var storageName   = '${toLower(replace(prefix, '-', ''))}st'
var containerName = 'assets'
var kvName        = '${prefix}-kv123'
var apimName      = '${prefix}-apim'
var apimPublisherEmail = 'demo@example.com'
var apimPublisherName  = 'Umbrella Demo'

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
    reserved: true // required for Linux
  }
}

// ── App Service — BROKEN ─────────────────────────────────────────────────
// MISCONFIG #6: httpsOnly off, TLS 1.0
// MISCONFIG #8: no system-assigned identity
// MISCONFIG #3: plain-text connection string in app settings
resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  // MISCONFIG #8: identity block omitted → no system-assigned identity
  properties: {
    serverFarmId: plan.id
    httpsOnly: false // MISCONFIG #6
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      minTlsVersion: '1.0' // MISCONFIG #6
      ftpsState: 'AllAllowed'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          // MISCONFIG #3: plain-text — not a Key Vault reference
          name: 'SqlConnectionString'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};User Id=${sqlAdminLogin};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        }
        {
          // Enables the /debug/exec endpoint (App Service runtime alert trigger)
          name: 'ENABLE_DEBUG_EXEC'
          value: 'true'
        }
      ]
    }
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
  location: sqlLocation
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'  // 1.0 rejected service-wide since 2024; misconfig #2 is the open firewall rule below
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: sqlLocation
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

// MISCONFIG #2: firewall open to the entire internet
resource sqlFirewallAll 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// "Allow Azure services" rule
resource sqlFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ── Storage Account ───────────────────────────────────────────────────────
// MISCONFIG #1: public blob access allowed
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true     // MISCONFIG #1
    minimumTlsVersion: 'TLS1_0'
    supportsHttpsTrafficOnly: false
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
    publicAccess: 'Blob' // MISCONFIG #1: anonymous read access
  }
}

// ── Key Vault ─────────────────────────────────────────────────────────────
// MISCONFIG #8: App Service has no access policy (no MI)
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: kvAdminObjectId
        permissions: {
          secrets: ['get', 'list', 'set', 'delete', 'recover', 'purge']
        }
      }
      // No entry for the App Service — it cannot read secrets (broken baseline)
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

// ── API Management ────────────────────────────────────────────────────────
// MISCONFIG #5: Developer SKU, no rate-limiting policy, subscriptionRequired = false
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
    subscriptionRequired: false // MISCONFIG #5: no subscription key
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

// MISCONFIG #5: no rate-limiting policy set at API or product level
// MISCONFIG #7: no diagnostic settings / no Log Analytics workspace

// ── Outputs ───────────────────────────────────────────────────────────────
output appUrl          string = 'https://${app.properties.defaultHostName}'
output apimGatewayUrl  string = apim.properties.gatewayUrl
output swaDefaultHost  string = swa.properties.defaultHostname
output sqlServerFqdn   string = sqlServer.properties.fullyQualifiedDomainName
output storageAccName  string = storage.name
output kvUri           string = kv.properties.vaultUri
