#!/usr/bin/env bash
# Unified prerequisites + Kubernetes check
# Usage: ./scripts/infra/check.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET_ENV="${1:-}"
ENVS=()
if [ -n "$TARGET_ENV" ]; then
    ENVS=("$TARGET_ENV")
else
    ENVS=("dev" "prod")
fi

source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

show_header

ERRORS=0

# One "group / name" line per check, mirroring the secrets "env / chart" style
TOOLS_BOX_LINES=""

tool_line() {
    local group="$1" name="$2" ok="$3"
    local line
    if [ "$ok" -eq 0 ]; then
        line="$(printf "  %s  %s" "$(gum_success --bold '✓')" "$group / $name")"
    else
        line="$(printf "  %s  %s" "$(gum_error --bold '✗')" "$group / $name")"
        ERRORS=$((ERRORS + 1))
    fi
    TOOLS_BOX_LINES="${TOOLS_BOX_LINES:+${TOOLS_BOX_LINES}$'\n'}${line}"
}

# ── CLI tools ─────────────────────────────────────────────────────────────────

for cmd in mise kubectl helm helmfile sops ansible poetry gum fzf jq yq; do
    command -v "$cmd" &>/dev/null && ok=0 || ok=1
    tool_line "cli" "$cmd" "$ok"
done

# ── Helm plugins ──────────────────────────────────────────────────────────────

HELM_PLUGINS=$(helm plugin list 2>/dev/null || true)
for plugin in secrets secrets-getter secrets-post-renderer diff; do
    echo "$HELM_PLUGINS" | grep -q "^$plugin" && ok=0 || ok=1
    tool_line "helm" "$plugin" "$ok"
done

# ── Kubernetes ────────────────────────────────────────────────────────────────

# Label the connection check with the active context (homelab-prod → prod)
ok=1
CTX_LABEL="cluster"
if command -v kubectl &>/dev/null; then
    ctx=$(kubectl config current-context 2>/dev/null || true)
    [ -n "$ctx" ] && CTX_LABEL="${ctx#homelab-}"
    gum spin --spinner pulse --padding="0 0 0 2" --title "  $CTX_LABEL cluster" \
        -- bash -c "kubectl cluster-info &>/dev/null" && ok=0 || ok=1
fi
tool_line "$CTX_LABEL" "Kubernetes connection" "$ok"

# ── Secrets ───────────────────────────────────────────────────────────────────

TEMPLATES_DIR="$ROOT_DIR/helmfile/secret-templates"
SECRETS_BOX_LINES=""

for template in "$TEMPLATES_DIR"/*.template.yaml; do
    [ -f "$template" ] || continue
    chart=$(basename "$template" .template.yaml)
    for env in "${ENVS[@]}"; do
        enc="$ROOT_DIR/helmfile/environments/$env/secrets/${chart}.enc.yaml"
        if [ -f "$enc" ]; then
            line="$(printf "  %s  %s" "$(gum_success --bold '✓')" "$env / $chart")"
        else
            line="$(printf "  %s  %s" "$(gum_error --bold '✗')" "$env / $chart")"
            ERRORS=$((ERRORS + 1))
        fi
        SECRETS_BOX_LINES="${SECRETS_BOX_LINES:+${SECRETS_BOX_LINES}$'\n'}${line}"
    done
done

# ── Boxes ─────────────────────────────────────────────────────────────────────

echo ""

# Pad the shorter column so both boxes render at the same height
tools_n=$(awk 'END { print NR }' <<<"$TOOLS_BOX_LINES")
secrets_n=$(awk 'END { print NR }' <<<"$SECRETS_BOX_LINES")
while [ "$tools_n" -lt "$secrets_n" ]; do
    TOOLS_BOX_LINES+=$'\n'
    tools_n=$((tools_n + 1))
done
while [ "$secrets_n" -lt "$tools_n" ]; do
    SECRETS_BOX_LINES+=$'\n'
    secrets_n=$((secrets_n + 1))
done

TOOLS_BOX=$(gum style \
    --border rounded \
    --border-foreground "$GUM_SECONDARY" \
    --padding "1 2" \
    "$(gum_secondary --bold 'Tools')" \
    "" \
    "$TOOLS_BOX_LINES")

SECRETS_BOX=$(gum style \
    --border rounded \
    --border-foreground "$GUM_SECONDARY" \
    --padding "1 2" \
    "$(gum_secondary --bold 'Secrets')" \
    "" \
    "$SECRETS_BOX_LINES")

gum join --horizontal "$TOOLS_BOX" "   " "$SECRETS_BOX"
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
    gum style \
        --border rounded \
        --border-foreground "$GUM_ERROR" \
        --padding "0 2" \
        "$(gum_error --bold "$ERRORS check(s) failed.") Run: mise install"
    exit 1
else
    gum style \
        --border double \
        --border-foreground "$GUM_SUCCESS" \
        --padding "1 4" \
        --margin "0 1" \
        --bold \
        "$(gum_success --bold "✓  All checks passed. 🎉")"
fi
