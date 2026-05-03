# Infrastructure (M1.3 — pre-Foundry skeleton)

Subscription-scope Bicep deployment driven by `azd`. Composes Azure Verified Modules (AVM) from the public Bicep registry. Foundry resources land separately in M1.6 (`infra/modules/foundry.bicep`).

## What this provisions

| Resource | AVM module | Purpose |
|---|---|---|
| Resource group | `resources/resource-group` | Holds everything; named `rg-procurement-${env}-${location}` |
| Log Analytics workspace | `operational-insights/workspace` | Sink for App Insights + future Container Apps + Foundry |
| Application Insights | `insights/component` | Workspace-based; consumed by FastAPI + Foundry exports |
| Key Vault | `key-vault/vault` | Soft-delete on (7-day), purge protection **off** for daily teardown |
| Storage account | `storage/storage-account` | Standard_LRS, blob container `documents` for the synthetic corpus |
| Container Registry | `container-registry/registry` | Basic SKU; admin user disabled |

## AVM module pins

Pinned versions (verified against `mcr.microsoft.com/v2/bicep/avm/res/...` at the time of this commit):

| Module | Pin |
|---|---|
| `avm/res/resources/resource-group` | `0.4.3` |
| `avm/res/operational-insights/workspace` | `0.15.0` |
| `avm/res/insights/component` | `0.7.1` |
| `avm/res/key-vault/vault` | `0.13.3` |
| `avm/res/storage/storage-account` | `0.32.0` |
| `avm/res/container-registry/registry` | `0.12.1` |

To re-check whether a newer minor is available:

```bash
curl -s https://mcr.microsoft.com/v2/bicep/avm/res/<provider>/<resource>/tags/list | jq '.tags | sort'
```

## Required environment variables

| Name | Used for | Default if unset |
|---|---|---|
| `OWNER_TAG` | `owner` tag applied to every resource | `unset` (resources will deploy but the tag will be literally `unset`) |

Set it before deploying:

```bash
export OWNER_TAG="your-name"
```

## Local lifecycle

The project runs on the **daily teardown / cold-start** discipline from [`PROJECT.md` §III.7](../docs/PROJECT.md). Bring it up at the start of a session, take it down at the end. M1.3 ships placeholder Makefile wrappers; M1.3.5 will add timing and history logging.

```bash
# Bring up — provisions infra + (later) deploys app
make azd-up

# Tear down — deletes the resource group, purges soft-deleted KV
make azd-down

# Status — shows whether the RG exists and lists resources
make azd-status
```

Under the hood:

- `azd up` → `az deployment sub create --template-file infra/main.bicep --parameters infra/main.bicepparam` against the subscription `azd` is logged into.
- `azd down --force --purge --no-prompt` → deletes the RG and purges any soft-deleted Key Vaults so the same name can be recreated next day.

## First-time setup (one per machine)

```bash
brew install azure-cli azure-dev    # az 2.85+, azd 1.24+
az login
azd auth login
azd init                            # only if no .azure/ directory yet
```

`azd init` will inherit the `name` from `azure.yaml` and create a local `.azure/<env>/` directory tracking the subscription, location, and outputs.

## Validating without deploying

```bash
az bicep build --file infra/main.bicep
az deployment sub validate \
  --location eastus2 \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

`az bicep build` is offline (after the first AVM module restore). `az deployment sub validate` requires `az login` against a real subscription.

## Notes on lifecycle correctness

The Bicep design is constrained by [`PROJECT.md` §III.7](../docs/PROJECT.md):

- **Key Vault** has `enablePurgeProtection: false` so `azd down --purge` can fully remove it; `enableSoftDelete: true` is forced by the platform but the 7-day retention is the minimum allowed.
- **Storage / ACR / KV names** are suffixed with `uniqueString(subscription().subscriptionId, resourceGroupName)` so they remain stable across `up`/`down` cycles within the same subscription.
- **No resources outside the RG** — every module deploys to `resourceGroup(resourceGroupName)` so `az group delete` (what `azd down` ultimately calls) cleans everything in one shot.

## What's deferred

- Azure Deployment Stacks (`az stack sub create ...`) for native drift detection — `azd` currently uses standard subscription deployments. Switching to Stacks is a future story; for now `azd down --force --purge` gives us the same cleanup guarantee.
- Private endpoints, customer-managed keys, network restrictions — production posture, documented in M4.7.
- All Foundry resources — M1.6.
