#!/usr/bin/env bash
# Preflight checks for the OpenBao post-deploy setup.
#
# Verifies every CLI tool and cluster resource that scripts/apps/setup-openbao.sh
# depends on, so setup fails fast with a clear report instead of part-way through
# (e.g. after generating unseal keys but before the ESO CRD is found).
#
# Set OPENBAO_PREFLIGHT_QUIET=1 to skip the banner and the success box — used when
# setup-openbao.sh runs this as an inline gate under its own header.
#
# Usage: ./scripts/apps/setup-openbao-preflight.sh [environment]   (prompts if omitted)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"

# Mirrors the constants in setup-openbao.sh
NAMESPACE="openbao-system"
ESO_NAMESPACE="external-secrets-system"
POD="openbao-0"
CSS_CRD="clustersecretstores.external-secrets.io"

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

# Select the target environment (prompts when no argument is given).
source "$SCRIPT_DIR/../lib/env.sh" "${1:-}"
KUBE_CONTEXT="homelab-$ENV"

if [ "${OPENBAO_PREFLIGHT_QUIET:-0}" != "1" ]; then
    clear
    show_header
fi
gum_secondary "  OpenBao setup preflight — env → $(gum_primary --bold "$ENV")"
echo ""

ERRORS=0
BOX_LINES=""

mark() {
    local group="$1" name="$2" ok="$3" line
    if [ "$ok" -eq 0 ]; then
        line="$(printf "  %s  %s" "$(gum_success --bold '✓')" "$group / $name")"
    else
        line="$(printf "  %s  %s" "$(gum_error --bold '✗')" "$group / $name")"
        ERRORS=$((ERRORS + 1))
    fi
    BOX_LINES="${BOX_LINES:+${BOX_LINES}$'\n'}${line}"
}

# Run a kubectl check under a spinner; pass 0/1 to mark based on its exit status.
check_resource() {
    local group="$1" name="$2"
    shift 2
    local ok=1
    if command -v kubectl &>/dev/null; then
        # `_ "$@"` forwards args safely; output is hidden so only the box shows.
        gum spin --spinner pulse --title "  $name" \
            -- bash -c 'kubectl "$@" >/dev/null 2>&1' _ --context "$KUBE_CONTEXT" "$@" && ok=0 || ok=1
    fi
    mark "$group" "$name" "$ok"
}

# ── CLI tools ─────────────────────────────────────────────────────────────────

for cmd in gum kubectl jq; do
    command -v "$cmd" &>/dev/null && ok=0 || ok=1
    mark "cli" "$cmd" "$ok"
done

# ── Cluster ─────────────────────────────────────────────────────────────────

check_resource "k8s"     "cluster connection"      cluster-info
check_resource "openbao" "$NAMESPACE namespace"    get namespace "$NAMESPACE" --request-timeout=10s
check_resource "openbao" "$POD pod"                get pod "$POD" -n "$NAMESPACE" --request-timeout=10s
check_resource "eso"     "$ESO_NAMESPACE namespace" get namespace "$ESO_NAMESPACE" --request-timeout=10s
check_resource "eso"     "ClusterSecretStore CRD"   get crd "$CSS_CRD" --request-timeout=10s

# ── Box ─────────────────────────────────────────────────────────────────────

echo ""
gum style \
    --border rounded \
    --border-foreground "$GUM_SECONDARY" \
    --padding "1 2" \
    "$(gum_secondary --bold 'OpenBao prerequisites')" \
    "" \
    "$BOX_LINES"
echo ""

# ── Summary ─────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
    gum style \
        --border rounded \
        --border-foreground "$GUM_ERROR" \
        --padding "0 2" \
        "$(gum_error --bold "$ERRORS check(s) failed.") Resolve the above before running OpenBao setup."
    exit 1
fi

if [ "${OPENBAO_PREFLIGHT_QUIET:-0}" = "1" ]; then
    success "Preflight checks passed."
else
    gum style \
        --border double \
        --border-foreground "$GUM_SUCCESS" \
        --padding "1 4" \
        --margin "0 1" \
        --bold \
        "$(gum_success --bold "✓  Ready for OpenBao setup. 🎉")"
fi
