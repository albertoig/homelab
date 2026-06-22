#!/usr/bin/env bash
# Unseal OpenBao with 3 of the 5 unseal keys.
#
# A lightweight counterpart to setup-openbao.sh for when a pod restart or node
# reboot leaves OpenBao sealed (there is no auto-unseal). It does NOT initialise,
# configure ESO, or touch the root token — it only unseals.
#
# Usage: ./scripts/apps/unseal-openbao.sh [environment]   (prompts if omitted)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"
source "$SCRIPT_DIR/../lib/openbao.sh"

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

# Select the target environment (prompts when no argument is given).
source "$SCRIPT_DIR/../lib/env.sh" "${1:-}"
KUBE_CONTEXT="homelab-$ENV"
ROOT_DNS=$(yq -r '.general.root_dns' "$SCRIPT_DIR/../../helmfile/environments/$ENV/config.yaml")
OPENBAO_URL="https://openbao.internal.${ROOT_DNS}"

clear
show_header
gum_secondary "  OpenBao unseal"
show_subheader "$ENV" "$KUBE_CONTEXT" "openbao=$OPENBAO_URL"

# Verify tools and cluster resources before touching OpenBao.
OPENBAO_PREFLIGHT_QUIET=1 "$SCRIPT_DIR/setup-openbao-preflight.sh" "$ENV" || exit 1
echo ""

# All cluster reads/writes target the selected environment's context
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }
kbao() { k exec -n "$NAMESPACE" "$POD" -- env BAO_ADDR="$BAO_ADDR" bao "$@"; }

# ── Wait for the pod and API ──────────────────────────────────────────────────

gum spin --spinner pulse --show-error \
    --title "  Waiting for $POD to start..." \
    -- kubectl --context "$KUBE_CONTEXT" wait pod "$POD" -n "$NAMESPACE" \
        --for=jsonpath='{.status.phase}'=Running --timeout=120s

STATUS=""
for _ in $(seq 1 30); do
    STATUS=$(kbao status -format=json 2>/dev/null || true)
    [ -n "$STATUS" ] && jq -e 'has("sealed")' <<<"$STATUS" >/dev/null 2>&1 && break
    STATUS=""
    sleep 2
done

if [ -z "$STATUS" ]; then
    error "OpenBao API at $BAO_ADDR did not become reachable inside $POD."
    exit 1
fi

INITIALIZED=$(jq -r '.initialized' <<<"$STATUS")
SEALED=$(jq -r '.sealed' <<<"$STATUS")

# ── Guards ────────────────────────────────────────────────────────────────────

if [ "$INITIALIZED" != "true" ]; then
    error "OpenBao is not initialised yet — run: mise run openbao:setup $ENV"
    exit 1
fi

if [ "$SEALED" = "false" ]; then
    info "OpenBao is already unsealed — nothing to do."
    echo ""
    exit 0
fi

# ── Unseal (3 of 5 keys) ─────────────────────────────────────────────────────

gum_accent --bold "  OpenBao is sealed — enter 3 unseal keys."
echo ""
for i in 1 2 3; do
    _key=$(gum input --password --prompt "  Unseal key $i/3: ") || { warn "Aborted."; exit 1; }
    [ -z "$_key" ] && { error "No key entered."; exit 1; }
    gum spin --spinner pulse --show-error \
        --title "  Applying unseal key $i/3..." \
        -- kubectl --context "$KUBE_CONTEXT" exec -n "$NAMESPACE" "$POD" -- \
            env BAO_ADDR="$BAO_ADDR" bao operator unseal "$_key"
done

if [ "$(kbao status -format=json 2>/dev/null | jq -r '.sealed')" = "true" ]; then
    error "OpenBao is still sealed — check the keys and retry."
    exit 1
fi

echo ""
gum style \
    --border rounded --border-foreground "$GUM_PRIMARY" \
    --align center --padding "1 4" --margin "1 2" \
    "$(gum_primary --bold "✓  OpenBao is unsealed.")"
