#!/usr/bin/env bash
# Configure OpenBao after initial helmfile deployment.
# Idempotent: skips if OpenBao is already initialised and unsealed.
#
# Steps performed:
#   1. Wait for OpenBao pod to be ready
#   2. Init OpenBao (generates unseal keys + root token)
#   3. Unseal (3 of 5 keys)
#   4. Enable KV v2 secrets engine at "secret/"
#   5. Create read-only ESO policy
#   6. Create ESO service token
#   7. Create Kubernetes secret for ESO authentication
#   8. Apply ClusterSecretStore pointing at OpenBao
#
# Usage: ./scripts/apps/setup-openbao.sh [environment]   (prompts if omitted)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"
source "$SCRIPT_DIR/../lib/openbao.sh"

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

# Select the target environment (prompts when no argument is given).
source "$SCRIPT_DIR/../lib/env.sh" "${1:-}"
KUBE_CONTEXT="homelab-$ENV"

clear
show_header
gum_secondary "  OpenBao post-deploy setup — env → $(gum_primary --bold "$ENV")"
echo ""

# Verify every tool and cluster resource is in place before touching OpenBao.
OPENBAO_PREFLIGHT_QUIET=1 "$SCRIPT_DIR/setup-openbao-preflight.sh" "$ENV" || exit 1
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

# All cluster reads/writes target the selected environment's context
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }

# Run a bao command inside the pod (unauthenticated)
kbao() {
    k exec -n "$NAMESPACE" "$POD" -- env BAO_ADDR="$BAO_ADDR" bao "$@"
}

ROOT_TOKEN=""

# ── Step 1: Wait for pod ──────────────────────────────────────────────────────

# OpenBao reports NotReady until it is unsealed (its readiness probe fails while
# sealed), and unsealing happens in step 4 below. Waiting for condition=Ready
# here would deadlock — the pod can only become Ready after this script unseals
# it. Wait for the container to be Running instead (enough to exec in), then poll
# the bao API, which answers even while sealed.
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

# ── Step 2: Check current state ───────────────────────────────────────────────

if [ -z "$STATUS" ]; then
    error "OpenBao API at $BAO_ADDR did not become reachable inside $POD."
    exit 1
fi

info "$POD is running and the OpenBao API is reachable."
echo ""

INITIALIZED=$(jq -r '.initialized' <<<"$STATUS")
SEALED=$(jq -r '.sealed' <<<"$STATUS")

if [ "$INITIALIZED" = "true" ] && [ "$SEALED" = "false" ]; then
    info "OpenBao is already initialised and unsealed — nothing to do."
    echo ""
    exit 0
fi

if [ "$INITIALIZED" = "true" ] && [ "$SEALED" = "true" ]; then
    gum style \
        --border rounded --border-foreground "$GUM_ACCENT" --padding "0 2" \
        "$(gum_accent --bold "OpenBao is initialised but sealed.")" \
        "" \
        "Unseal manually: kubectl --context $KUBE_CONTEXT exec -n $NAMESPACE $POD -- bao operator unseal"
    exit 1
fi

# ── Step 3: Init ──────────────────────────────────────────────────────────────

gum_secondary --bold "  Initialising OpenBao (5 shares, threshold 3)..."
echo ""

INIT_JSON=$(kbao operator init -key-shares=5 -key-threshold=3 -format=json)
ROOT_TOKEN=$(jq -r '.root_token' <<<"$INIT_JSON")

mapfile -t UNSEAL_KEYS < <(jq -r '.unseal_keys_b64[]' <<<"$INIT_JSON")

KEY_DISPLAY=""
for i in "${!UNSEAL_KEYS[@]}"; do
    KEY_DISPLAY+="Unseal Key $((i+1)): ${UNSEAL_KEYS[$i]}"$'\n'
done

gum style \
    --border rounded --border-foreground "$GUM_ERROR" --padding "1 2" \
    "$(gum_error --bold "⚠  SAVE THESE NOW — they cannot be recovered")" \
    "" \
    "${KEY_DISPLAY}Root Token:  $ROOT_TOKEN"

echo ""
gum confirm "I have saved the unseal keys and root token securely." || {
    warn "Aborted. OpenBao is initialised but not unsealed — save the output above and re-run."
    exit 1
}
echo ""

# ── Step 4: Unseal (3 of 5 keys) ─────────────────────────────────────────────

for i in 0 1 2; do
    gum spin --spinner pulse \
        --title "  Applying unseal key $((i+1))/3..." \
        -- kubectl --context "$KUBE_CONTEXT" exec -n "$NAMESPACE" "$POD" -- \
            env BAO_ADDR="$BAO_ADDR" bao operator unseal "${UNSEAL_KEYS[$i]}"
    info "Unseal key $((i+1))/3 accepted."
done

echo ""
info "OpenBao unsealed."
echo ""

# ── Step 5: Enable KV v2 ─────────────────────────────────────────────────────

gum spin --spinner pulse --show-error \
    --title "  Enabling KV v2 at '$KV_PATH/'..." \
    -- kubectl --context "$KUBE_CONTEXT" exec -n "$NAMESPACE" "$POD" -- \
        env BAO_ADDR="$BAO_ADDR" BAO_TOKEN="$ROOT_TOKEN" \
        bao secrets enable -path="$KV_PATH" -version=2 kv

info "KV v2 enabled at $KV_PATH/."
echo ""

# ── Step 6: Create ESO read-only policy ──────────────────────────────────────

_policy=$(mktemp /tmp/bao-policy.XXXXXX.hcl)
chmod 600 "$_policy"
cat > "$_policy" <<'HCL'
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
HCL

gum spin --spinner pulse --show-error \
    --title "  Writing policy '$ESO_POLICY'..." \
    -- bash -c "kubectl --context '$KUBE_CONTEXT' exec -i -n '$NAMESPACE' '$POD' -- \
        env BAO_ADDR='$BAO_ADDR' BAO_TOKEN='$ROOT_TOKEN' \
        bao policy write '$ESO_POLICY' - < '$_policy'"

rm -f "$_policy"
info "Policy '$ESO_POLICY' created."
echo ""

# ── Step 7: Create ESO service token ─────────────────────────────────────────

ESO_TOKEN=$(k exec -n "$NAMESPACE" "$POD" -- \
    env BAO_ADDR="$BAO_ADDR" BAO_TOKEN="$ROOT_TOKEN" \
    bao token create \
        -policy="$ESO_POLICY" \
        -display-name="external-secrets-operator" \
        -no-default-policy \
        -orphan \
        -field=token)
info "ESO service token created."
echo ""

# ── Step 8: Kubernetes secret ─────────────────────────────────────────────────

gum spin --spinner pulse --show-error \
    --title "  Applying secret '$ESO_SECRET' in $ESO_NAMESPACE..." \
    -- bash -c "kubectl --context '$KUBE_CONTEXT' create secret generic '$ESO_SECRET' \
        --from-literal=token='$ESO_TOKEN' \
        --namespace '$ESO_NAMESPACE' \
        --dry-run=client -o yaml | kubectl --context '$KUBE_CONTEXT' apply -f -"

info "Secret '$ESO_SECRET' applied."
echo ""

# ── Step 9: ClusterSecretStore ────────────────────────────────────────────────

_css=$(mktemp /tmp/cluster-secret-store.XXXXXX.yaml)
chmod 600 "$_css"
cat > "$_css" <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: $CSS_NAME
spec:
  provider:
    vault:
      server: "http://openbao-internal.${NAMESPACE}.svc.cluster.local:8200"
      path: "$KV_PATH"
      version: "v2"
      auth:
        tokenSecretRef:
          name: $ESO_SECRET
          namespace: $ESO_NAMESPACE
          key: token
EOF

gum spin --spinner pulse --show-error \
    --title "  Applying ClusterSecretStore '$CSS_NAME'..." \
    -- kubectl --context "$KUBE_CONTEXT" apply -f "$_css"

rm -f "$_css"
info "ClusterSecretStore '$CSS_NAME' applied."
echo ""

# ── Done ──────────────────────────────────────────────────────────────────────

gum style \
    --border rounded --border-foreground "$GUM_PRIMARY" \
    --align center --padding "1 4" --margin "1 2" \
    "$(gum_primary --bold "✓  OpenBao is configured and ready.")" \
    "" \
    "Environment:        $ENV" \
    "KV engine:          $KV_PATH/ (v2)" \
    "ESO policy:         $ESO_POLICY" \
    "ClusterSecretStore: $CSS_NAME"
