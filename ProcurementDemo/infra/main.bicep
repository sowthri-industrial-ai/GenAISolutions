// =============================================================================
// ProcurementDemo — pre-Foundry infra skeleton (M1.3)
// Subscription-scope deployment; resource group + monitoring + storage + KV + ACR.
// AVM modules pinned per infra/README.md "AVM module pins" table.
// Foundry resources are added in M1.6 via infra/modules/foundry.bicep.
// =============================================================================

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string

@description('Environment tag (single-environment project, e.g. dev).')
param env string

@description('Owner tag value — set via OWNER_TAG environment variable.')
param ownerTag string

@description('Resource group name. Pattern: rg-procurement-<env>-<location>.')
param resourceGroupName string

var tags = {
  project: 'procurement-agentic-demo'
  env: env
  owner: ownerTag
}

// Suffix for globally-namespaced resources (storage, ACR, KV).
var uniqueSuffix = uniqueString(subscription().subscriptionId, resourceGroupName)

// -----------------------------------------------------------------------------
// Resource group
// -----------------------------------------------------------------------------
module rg 'br/public:avm/res/resources/resource-group:0.4.3' = {
  name: 'deploy-rg-${env}'
  scope: subscription()
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Log Analytics workspace
// -----------------------------------------------------------------------------
module logs 'br/public:avm/res/operational-insights/workspace:0.15.0' = {
  name: 'deploy-logs-${env}'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    name: 'log-procurement-${env}'
    location: location
    skuName: 'PerGB2018'
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Application Insights (workspace-based, linked to Log Analytics above)
// -----------------------------------------------------------------------------
module appi 'br/public:avm/res/insights/component:0.7.1' = {
  name: 'deploy-appi-${env}'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    name: 'appi-procurement-${env}'
    location: location
    workspaceResourceId: logs.outputs.resourceId
    applicationType: 'web'
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Key Vault — purge protection OFF so daily teardown can recreate same name.
// Soft delete cannot be disabled (Azure platform requirement); 7-day retention
// keeps the soft-deleted vault around briefly but `azd down --purge` purges it.
// See PROJECT.md §III.7 — Lifecycle & Cost Discipline.
// -----------------------------------------------------------------------------
module kv 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'deploy-kv-${env}'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    name: take('kv-proc-${env}-${uniqueSuffix}', 24)
    location: location
    enablePurgeProtection: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Storage account + 'documents' blob container
// -----------------------------------------------------------------------------
module storage 'br/public:avm/res/storage/storage-account:0.32.0' = {
  name: 'deploy-st-${env}'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    name: take('stproc${env}${uniqueSuffix}', 24)
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    blobServices: {
      containers: [
        {
          name: 'documents'
          publicAccess: 'None'
        }
      ]
    }
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Azure Container Registry — Basic SKU, admin user disabled.
// Managed-identity pulls are wired in M1.4 / M1.6.
// -----------------------------------------------------------------------------
module acr 'br/public:avm/res/container-registry/registry:0.12.1' = {
  name: 'deploy-acr-${env}'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    name: take('acrproc${env}${uniqueSuffix}', 50)
    location: location
    acrSku: 'Basic'
    acrAdminUserEnabled: false
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Outputs — consumed by future stories (M1.4 onward).
// -----------------------------------------------------------------------------
output resourceGroupName string = resourceGroupName
output logAnalyticsWorkspaceId string = logs.outputs.resourceId
output applicationInsightsConnectionString string = appi.outputs.connectionString
output keyVaultUri string = kv.outputs.uri
output storageAccountName string = storage.outputs.name
output acrLoginServer string = acr.outputs.loginServer
