#!/usr/bin/env bash
# infra/scripts/azd-lifecycle.sh
# Implementation of `make azd-up` / `make azd-down` / `make azd-status`.
# Per PROJECT.md §III.7 (Lifecycle & Cost Discipline).
#
# Usage: bash infra/scripts/azd-lifecycle.sh {up|down|status}
# Env vars consumed:
#   OWNER_TAG       (required for `up`) — applied as the `owner` Azure tag
#   AZD_ENV_NAME    (default: procurement-dev)
#   AZD_LOCATION    (default: eastus2)

set -u
set -o pipefail

AZD_ENV_NAME="${AZD_ENV_NAME:-procurement-dev}"
AZD_LOCATION="${AZD_LOCATION:-eastus2}"
HISTORY_FILE="tests/cold-start-history.csv"

# ---- color helpers (TTY only) ------------------------------------------------
if [ -t 1 ]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_DIM=$'\033[2m'
    C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_DIM=""; C_RESET=""
fi

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

log_info() { printf '%s[%s]%s %s\n'  "$C_DIM"    "$(ts)" "$C_RESET" "$*"; }
log_warn() { printf '%s[%s] %s%s\n' "$C_YELLOW" "$(ts)" "$*" "$C_RESET"; }
log_ok()   { printf '%s[%s] %s%s\n' "$C_GREEN"  "$(ts)" "$*" "$C_RESET"; }
log_err()  { printf '%s[%s] %s%s\n' "$C_RED"    "$(ts)" "$*" "$C_RESET" >&2; }

# ---- preconditions ----------------------------------------------------------
require_owner_tag() {
    if [ -z "${OWNER_TAG:-}" ] || [ "${OWNER_TAG}" = "unset" ]; then
        log_err "OWNER_TAG environment variable is not set."
        log_err "  Run:  export OWNER_TAG=\"your-name\"   then re-run make azd-up"
        exit 2
    fi
}

require_az_login() {
    if ! az account show >/dev/null 2>&1; then
        log_err "Azure CLI is not logged in. Run:  az login"
        exit 2
    fi
}

ensure_history_file() {
    if [ ! -f "$HISTORY_FILE" ]; then
        log_warn "Creating $HISTORY_FILE (first run)."
        mkdir -p "$(dirname "$HISTORY_FILE")"
        cat > "$HISTORY_FILE" <<'CSV'
# tests/cold-start-history.csv — local development log of azd lifecycle runs.
# Appended by `make azd-up` and `make azd-down`. Used as the cold-start
# regression baseline against the ≤10-minute target in PROJECT.md §III.7.
# This is a development log, not a production report. Free to prune or edit.
# Lines starting with `#` are comments and ignored by readers.
timestamp_iso,command,success,duration_seconds,resource_count,notes
CSV
    fi
}

ensure_azd_env() {
    # azd needs an active env with subscription + location before `up --no-prompt`.
    # This is idempotent: if no env exists we create one; in either case we
    # (re-)assert AZURE_SUBSCRIPTION_ID and AZURE_LOCATION on the active env.
    local sub
    sub="$(az account show --query id -o tsv)"

    if ! azd env list --output json 2>/dev/null | grep -q '"Name"'; then
        log_info "No azd env found — creating env=$AZD_ENV_NAME sub=$sub location=$AZD_LOCATION"
        azd env new "$AZD_ENV_NAME" \
            --subscription "$sub" \
            --location "$AZD_LOCATION" \
            --no-prompt >/dev/null
    fi

    azd env set AZURE_SUBSCRIPTION_ID "$sub"  >/dev/null
    azd env set AZURE_LOCATION        "$AZD_LOCATION" >/dev/null
}

# ---- helpers ----------------------------------------------------------------
get_rg_name() {
    # Prefer the explicit Bicep output (resourceGroupName); fall back to the
    # azd convention (AZURE_RESOURCE_GROUP), which is only set automatically
    # for resource-group-scoped deployments — not for our subscription-scoped one.
    azd env get-values 2>/dev/null \
        | awk -F= '
            /^resourceGroupName=/    {gsub(/"/,"",$2); rg=$2}
            /^AZURE_RESOURCE_GROUP=/ {if (rg=="") {gsub(/"/,"",$2); rg=$2}}
            END {print rg}'
}

append_history() {
    # args: command, success(true|false), duration_seconds, resource_count, notes
    printf '%s,%s,%s,%s,%s,%s\n' \
        "$(ts)" "$1" "$2" "$3" "$4" "$5" >> "$HISTORY_FILE"
}

show_recent_history() {
    if [ ! -f "$HISTORY_FILE" ]; then
        log_info "No history file yet."
        return
    fi
    log_info "Recent lifecycle events (last 5):"
    grep -v '^#' "$HISTORY_FILE" | tail -n 5 | sed 's/^/    /'
}

print_portal_link() {
    local rg="$1"
    local sub_id tenant_id
    sub_id="$(az account show --query id -o tsv 2>/dev/null)"
    tenant_id="$(az account show --query tenantId -o tsv 2>/dev/null)"
    if [ -n "$sub_id" ] && [ -n "$rg" ]; then
        printf '    Portal: https://portal.azure.com/#@%s/resource/subscriptions/%s/resourceGroups/%s/overview\n' \
            "$tenant_id" "$sub_id" "$rg"
    fi
}

# ---- commands ---------------------------------------------------------------
cmd_up() {
    local start end duration rg count notes=""
    start=$(date +%s)
    log_warn "make azd-up — starting"

    require_owner_tag
    require_az_login
    ensure_history_file
    ensure_azd_env

    # Make OWNER_TAG visible to the Bicep compile via env vars azd inherits.
    azd env set OWNER_TAG "$OWNER_TAG" >/dev/null

    if azd up --no-prompt; then
        end=$(date +%s); duration=$((end - start))
        rg="$(get_rg_name)"
        count="$(az resource list -g "$rg" --query "length(@)" -o tsv 2>/dev/null || echo 0)"
        # Heuristic for idempotent runs: re-deploys with no diff finish quickly.
        if [ "$duration" -lt 120 ]; then
            notes="likely-noop"
        fi
        append_history "azd-up" "true" "$duration" "$count" "$notes"

        log_ok "azd-up succeeded in ${duration}s — RG=${rg}, ${count} resources${notes:+ (${notes})}"
        echo
        log_info "Resources in $rg:"
        az resource list -g "$rg" --output table 2>/dev/null | sed 's/^/    /'
        echo
        print_portal_link "$rg"
        return 0
    else
        end=$(date +%s); duration=$((end - start))
        append_history "azd-up" "false" "$duration" "0" "FAILED"
        log_err "azd-up failed after ${duration}s"
        log_err "  Check the azd output above for the failing Bicep module / ARM error."
        log_err "  Detailed deployment log: az deployment sub list --query \"[?contains(name, 'main-')].{name:name,state:properties.provisioningState}\" -o table"
        exit 1
    fi
}

cmd_down() {
    local start end duration rg
    start=$(date +%s)
    log_warn "make azd-down — starting"

    require_az_login
    ensure_history_file

    rg="$(get_rg_name)"
    if [ -z "$rg" ]; then
        log_info "No azd env / no resource group recorded — nothing to tear down."
        append_history "azd-down" "true" "0" "0" "no-env"
        return 0
    fi

    if ! az group show --name "$rg" >/dev/null 2>&1; then
        log_ok "Resource group $rg already gone — nothing to do."
        append_history "azd-down" "true" "0" "0" "already-gone"
        return 0
    fi

    if azd down --force --purge --no-prompt; then
        end=$(date +%s); duration=$((end - start))

        # Verify the RG is actually gone.
        if [ "$(az group exists --name "$rg")" = "false" ]; then
            append_history "azd-down" "true" "$duration" "0" ""
            log_ok "azd-down succeeded in ${duration}s — RG ${rg} fully removed."
            return 0
        else
            append_history "azd-down" "false" "$duration" "0" "rg-still-exists"
            log_err "azd reported success but RG ${rg} still exists."
            exit 1
        fi
    else
        end=$(date +%s); duration=$((end - start))
        append_history "azd-down" "false" "$duration" "0" "FAILED"
        log_err "azd-down failed after ${duration}s — see output above."
        exit 1
    fi
}

cmd_status() {
    ensure_history_file

    local rg
    rg="$(get_rg_name)"

    if [ -z "$rg" ]; then
        log_info "No azd env initialised. Run: make azd-up"
        echo
        show_recent_history
        return 0
    fi

    if ! az account show >/dev/null 2>&1; then
        log_warn "Resource group from azd env: $rg"
        log_warn "Cannot query Azure — not logged in. Run: az login"
        echo
        show_recent_history
        return 0
    fi

    if [ "$(az group exists --name "$rg")" = "true" ]; then
        log_ok "Resource group $rg — EXISTS"
        local count
        count="$(az resource list -g "$rg" --query "length(@)" -o tsv 2>/dev/null || echo 0)"
        log_info "Resources ($count):"
        az resource list -g "$rg" --output table 2>/dev/null | sed 's/^/    /'
        echo
        print_portal_link "$rg"
        echo
        log_info "Cost-day estimate: n/a (Azure cost data has 24h+ latency; check Cost Mgmt)"
    else
        log_warn "Resource group $rg — NOT PROVISIONED"
    fi

    echo
    show_recent_history
}

# ---- dispatch ---------------------------------------------------------------
case "${1:-}" in
    up)     cmd_up ;;
    down)   cmd_down ;;
    status) cmd_status ;;
    *)
        log_err "Usage: $0 {up|down|status}"
        exit 64
        ;;
esac
