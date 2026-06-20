#!/usr/bin/env bash
# Configure OpenBao after initial helmfile deployment.
#
# Idempotent and resumable: every step is create-or-update, so a re-run repairs
# whatever a previous run left unfinished without ever re-initialising OpenBao or
# regenerating the unseal keys / root token.
#
#   - Already initialised + unsealed + ClusterSecretStore Ready → no-op.
#   - Already initialised but configuration incomplete → prompts for the saved
#     root token and re-applies the KV mount, policy, token and store.
#   - Sealed (e.g. after a node reboot) → prompts for 3 unseal keys, then continues.
#   - Never initialised → initialises, shows the keys to save, unseals, configures.
#
# Steps performed:
#   1. Wait for the OpenBao pod to start and the API to answer
#   2. Initialise (only when never initialised) — generates unseal keys + root token
#   3. Unseal if sealed (3 keys; freshly generated, or prompted on a re-run)
#   4. Obtain the root token (from init, or prompted) for the configuration steps
#   5. Enable KV v2 secrets engine at "secret/"
#   6. Write the read-only ESO policy
#   7. Ensure the ESO service token + its Kubernetes secret
#   8. Apply the ClusterSecretStore pointing at OpenBao
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

# Run a bao command in the pod, unauthenticated (status / init / unseal)
kbao() {
    k exec -n "$NAMESPACE" "$POD" -- env BAO_ADDR="$BAO_ADDR" bao "$@"
}

# Run a bao command in the pod authenticated with $ROOT_TOKEN
kbao_auth() {
    k exec -n "$NAMESPACE" "$POD" -- \
        env BAO_ADDR="$BAO_ADDR" BAO_TOKEN="$ROOT_TOKEN" bao "$@"
}

ROOT_TOKEN=""

# ── Step 1: Wait for pod ──────────────────────────────────────────────────────

# OpenBao reports NotReady until it is unsealed (its readiness probe fails while
# sealed), and unsealing happens further down. Waiting for condition=Ready here
# would deadlock — the pod can only become Ready after this script unseals it.
# Wait for the container to be Running instead (enough to exec in), then poll the
# bao API, which answers even while sealed.
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

info "$POD is running and the OpenBao API is reachable."
echo ""

INITIALIZED=$(jq -r '.initialized' <<<"$STATUS")
SEALED=$(jq -r '.sealed' <<<"$STATUS")

# ── Step 2: Initialise (only when OpenBao has never been initialised) ─────────

if [ "$INITIALIZED" = "false" ]; then
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

    for i in 0 1 2; do
        gum spin --spinner pulse \
            --title "  Applying unseal key $((i+1))/3..." \
            -- kubectl --context "$KUBE_CONTEXT" exec -n "$NAMESPACE" "$POD" -- \
                env BAO_ADDR="$BAO_ADDR" bao operator unseal "${UNSEAL_KEYS[$i]}"
        info "Unseal key $((i+1))/3 accepted."
    done
    SEALED="false"
    echo ""
    info "OpenBao initialised and unsealed."
    echo ""
else
    info "OpenBao is already initialised."
    echo ""
fi

# ── Step 3: Unseal if a previous run or a reboot left it sealed ───────────────

if [ "$SEALED" = "true" ]; then
    gum_accent --bold "  OpenBao is sealed — enter 3 unseal keys to continue."
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
    info "OpenBao unsealed."
    echo ""
fi

# Already fully configured? If the store is Ready, everything downstream works,
# so re-running is a no-op and we never need the root token.
if [ -z "$ROOT_TOKEN" ]; then
    CSS_READY=$(k get clustersecretstore "$CSS_NAME" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    if [ "$CSS_READY" = "True" ]; then
        info "Already configured — ClusterSecretStore '$CSS_NAME' is Ready. Nothing to do."
        echo ""
        exit 0
    fi
fi

# ── Step 4: Obtain a privileged token for the configuration steps ────────────
# A fresh init already produced the root token; on a re-run the operator must
# supply it (this script never stores it).

if [ -z "$ROOT_TOKEN" ]; then
    ROOT_TOKEN=$(gum input --password \
        --prompt "  Root token (needed to finish configuring ESO): ") \
        || { warn "Aborted."; exit 1; }
    [ -z "$ROOT_TOKEN" ] && { error "A root token is required to configure ESO."; exit 1; }
    if ! kbao_auth token lookup &>/dev/null; then
        error "That token could not be validated against OpenBao."
        exit 1
    fi
    info "Root token accepted."
    echo ""
fi

# ── Step 5: Enable KV v2 (skip if already mounted) ───────────────────────────

if kbao_auth secrets list -format=json 2>/dev/null \
    | jq -e --arg p "$KV_PATH/" 'has($p)' >/dev/null; then
    info "KV v2 already enabled at $KV_PATH/."
else
    gum spin --spinner pulse --show-error \
        --title "  Enabling KV v2 at '$KV_PATH/'..." \
        -- kubectl --context "$KUBE_CONTEXT" exec -n "$NAMESPACE" "$POD" -- \
            env BAO_ADDR="$BAO_ADDR" BAO_TOKEN="$ROOT_TOKEN" \
            bao secrets enable -path="$KV_PATH" -version=2 kv
    info "KV v2 enabled at $KV_PATH/."
fi
echo ""

# ── Step 6: Write the ESO read-only policy (idempotent overwrite) ────────────

_policy=$(mktemp /tmp/bao-policy.XXXXXX.hcl)
chmod 600 "$_policy"
cat > "$_policy" <<'HCL'
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
# ESO validates the store by looking up and renewing its own token; the token is
# created with -no-default-policy, so these capabilities must be granted here.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
HCL

gum spin --spinner pulse --show-error \
    --title "  Writing policy '$ESO_POLICY'..." \
    -- bash -c "kubectl --context '$KUBE_CONTEXT' exec -i -n '$NAMESPACE' '$POD' -- \
        env BAO_ADDR='$BAO_ADDR' BAO_TOKEN='$ROOT_TOKEN' \
        bao policy write '$ESO_POLICY' - < '$_policy'"

rm -f "$_policy"
info "Policy '$ESO_POLICY' written."
echo ""

# ── Step 7: Ensure the ESO token and its Kubernetes secret ───────────────────
# Reuse the existing secret if present so re-runs don't orphan a fresh token each
# time; the policy write above keeps that token's permissions current. Delete the
# secret to force a new token.

if k get secret "$ESO_SECRET" -n "$ESO_NAMESPACE" &>/dev/null; then
    info "ESO token secret '$ESO_SECRET' already exists — reusing."
else
    ESO_TOKEN=$(kbao_auth token create \
        -policy="$ESO_POLICY" \
        -display-name="external-secrets-operator" \
        -no-default-policy \
        -orphan \
        -field=token)
    gum spin --spinner pulse --show-error \
        --title "  Creating secret '$ESO_SECRET' in $ESO_NAMESPACE..." \
        -- bash -c "kubectl --context '$KUBE_CONTEXT' create secret generic '$ESO_SECRET' \
            --from-literal=token='$ESO_TOKEN' \
            --namespace '$ESO_NAMESPACE' \
            --dry-run=client -o yaml | kubectl --context '$KUBE_CONTEXT' apply -f -"
    info "ESO service token created and stored."
fi
echo ""

# ── Step 8: Apply the ClusterSecretStore (idempotent apply) ──────────────────

_css=$(mktemp /tmp/cluster-secret-store.XXXXXX.yaml)
chmod 600 "$_css"
cat > "$_css" <<EOF
apiVersion: external-secrets.io/v1
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
