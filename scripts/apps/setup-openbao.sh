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
# Usage: ./scripts/apps/setup-openbao.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"

NAMESPACE="openbao-system"
ESO_NAMESPACE="external-secrets-system"
POD="openbao-0"
BAO_ADDR="http://127.0.0.1:8200"
KV_PATH="secret"
ESO_POLICY="eso-read"
ESO_SECRET="openbao-eso-token"
CSS_NAME="openbao"

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

clear
show_header
gum_secondary "  OpenBao post-deploy setup"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

# Run a bao command inside the pod (unauthenticated)
kbao() {
    kubectl exec -n "$NAMESPACE" "$POD" -- env BAO_ADDR="$BAO_ADDR" bao "$@"
}

ROOT_TOKEN=""

# ── Step 1: Wait for pod ──────────────────────────────────────────────────────

gum spin --spinner pulse --show-error \
    --title "  Waiting for $POD to be ready..." \
    -- kubectl wait pod "$POD" -n "$NAMESPACE" \
        --for=condition=Ready --timeout=120s

gum log --level info "$POD is ready."
echo ""

# ── Step 2: Check current state ───────────────────────────────────────────────

STATUS=$(kbao status -format=json 2>/dev/null || true)

if [ -z "$STATUS" ]; then
    gum log --level error "Could not reach OpenBao inside $POD at $BAO_ADDR."
    exit 1
fi

INITIALIZED=$(jq -r '.initialized' <<<"$STATUS")
SEALED=$(jq -r '.sealed' <<<"$STATUS")

if [ "$INITIALIZED" = "true" ] && [ "$SEALED" = "false" ]; then
    gum log --level info "OpenBao is already initialised and unsealed — nothing to do."
    echo ""
    exit 0
fi

if [ "$INITIALIZED" = "true" ] && [ "$SEALED" = "true" ]; then
    gum style \
        --border rounded --border-foreground "$GUM_ACCENT" --padding "0 2" \
        "$(gum_accent --bold "OpenBao is initialised but sealed.")" \
        "" \
        "Unseal manually: kubectl exec -n $NAMESPACE $POD -- bao operator unseal"
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
        -- kubectl exec -n "$NAMESPACE" "$POD" -- \
            env BAO_ADDR="$BAO_ADDR" bao operator unseal "${UNSEAL_KEYS[$i]}"
    gum log --level info "Unseal key $((i+1))/3 accepted."
done

echo ""
gum log --level info "OpenBao unsealed."
echo ""

# ── Step 5: Enable KV v2 ─────────────────────────────────────────────────────

gum spin --spinner pulse --show-error \
    --title "  Enabling KV v2 at '$KV_PATH/'..." \
    -- kubectl exec -n "$NAMESPACE" "$POD" -- \
        env BAO_ADDR="$BAO_ADDR" BAO_TOKEN="$ROOT_TOKEN" \
        bao secrets enable -path="$KV_PATH" -version=2 kv

gum log --level info "KV v2 enabled at $KV_PATH/."
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
    -- bash -c "kubectl exec -i -n '$NAMESPACE' '$POD' -- \
        env BAO_ADDR='$BAO_ADDR' BAO_TOKEN='$ROOT_TOKEN' \
        bao policy write '$ESO_POLICY' - < '$_policy'"

rm -f "$_policy"
gum log --level info "Policy '$ESO_POLICY' created."
echo ""

# ── Step 7: Create ESO service token ─────────────────────────────────────────

ESO_TOKEN=$(kubectl exec -n "$NAMESPACE" "$POD" -- \
    env BAO_ADDR="$BAO_ADDR" BAO_TOKEN="$ROOT_TOKEN" \
    bao token create \
        -policy="$ESO_POLICY" \
        -display-name="external-secrets-operator" \
        -no-default-policy \
        -orphan \
        -field=token)
gum log --level info "ESO service token created."
echo ""

# ── Step 8: Kubernetes secret ─────────────────────────────────────────────────

gum spin --spinner pulse --show-error \
    --title "  Applying secret '$ESO_SECRET' in $ESO_NAMESPACE..." \
    -- bash -c "kubectl create secret generic '$ESO_SECRET' \
        --from-literal=token='$ESO_TOKEN' \
        --namespace '$ESO_NAMESPACE' \
        --dry-run=client -o yaml | kubectl apply -f -"

gum log --level info "Secret '$ESO_SECRET' applied."
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
    -- kubectl apply -f "$_css"

rm -f "$_css"
gum log --level info "ClusterSecretStore '$CSS_NAME' applied."
echo ""

# ── Done ──────────────────────────────────────────────────────────────────────

gum style \
    --border rounded --border-foreground "$GUM_PRIMARY" \
    --align center --padding "1 4" --margin "1 2" \
    "$(gum_primary --bold "✓  OpenBao is configured and ready.")" \
    "" \
    "KV engine:          $KV_PATH/ (v2)" \
    "ESO policy:         $ESO_POLICY" \
    "ClusterSecretStore: $CSS_NAME"
