#!/usr/bin/env bash
# Unified prerequisites + Kubernetes check
# Usage: ./scripts/check.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/header.sh"

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

show_header

ERRORS=0

# ── Helpers ───────────────────────────────────────────────────────────────────

section() {
    gum style --foreground 99 --bold "  $*"
    echo ""
}

check_cmd() {
    local cmd="$1"
    local path
    if path=$(command -v "$cmd" 2>/dev/null); then
        gum log --level info "$cmd" path="$path"
    else
        gum log --level error "$cmd — not found"
        ERRORS=$((ERRORS + 1))
    fi
}

# ── Tool manager ──────────────────────────────────────────────────────────────

section "Tool manager"
check_cmd mise
echo ""

# ── CLI tools ─────────────────────────────────────────────────────────────────

section "CLI tools"
for cmd in kubectl helm helmfile sops ansible poetry gum fzf; do
    check_cmd "$cmd"
done
echo ""

# ── Helm plugins ──────────────────────────────────────────────────────────────

section "Helm plugins"

TMP_PLUGINS=$(mktemp)
gum spin \
    --spinner pulse \
    --title "  Loading Helm plugins..." \
    -- bash -c "helm plugin list > '$TMP_PLUGINS' 2>/dev/null" || true
HELM_PLUGINS=$(cat "$TMP_PLUGINS")
rm -f "$TMP_PLUGINS"

for plugin in secrets secrets-getter secrets-post-renderer diff; do
    if echo "$HELM_PLUGINS" | grep -q "^$plugin"; then
        gum log --level info "helm plugin: $plugin"
    else
        gum log --level error "helm plugin: $plugin — not installed"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# ── Kubernetes ────────────────────────────────────────────────────────────────

section "Kubernetes"

if ! command -v kubectl &>/dev/null; then
    gum log --level error "kubectl not found — skipping cluster checks"
    ERRORS=$((ERRORS + 1))
else
    if gum spin \
        --spinner pulse \
        --title "  Checking cluster access..." \
        -- bash -c "kubectl cluster-info &>/dev/null"; then
        gum log --level info "Cluster is reachable"
    else
        gum log --level error "Cannot reach Kubernetes cluster"
        ERRORS=$((ERRORS + 1))
    fi

    TMP_VER=$(mktemp)
    gum spin \
        --spinner pulse \
        --title "  Fetching server version..." \
        -- bash -c "kubectl version -o json > '$TMP_VER' 2>/dev/null" || true
    KUBE_JSON=$(cat "$TMP_VER")
    rm -f "$TMP_VER"

    MAJOR=$(echo "$KUBE_JSON" | awk '/"serverVersion"/,/\}/' | grep '"major"' | head -1 | tr -dc '0-9')
    MINOR=$(echo "$KUBE_JSON" | awk '/"serverVersion"/,/\}/' | grep '"minor"' | head -1 | tr -dc '0-9')

    REQUIRED_MAJOR=1
    REQUIRED_MINOR=33

    if [ -z "$MAJOR" ] || [ -z "$MINOR" ]; then
        gum log --level error "Could not determine Kubernetes server version"
        ERRORS=$((ERRORS + 1))
    elif [ "$MAJOR" -gt "$REQUIRED_MAJOR" ] || \
         { [ "$MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$MINOR" -ge "$REQUIRED_MINOR" ]; }; then
        gum log --level info "Kubernetes v${MAJOR}.${MINOR}" required=">=${REQUIRED_MAJOR}.${REQUIRED_MINOR}"
    else
        gum log --level error "Kubernetes v${MAJOR}.${MINOR} — requires >= ${REQUIRED_MAJOR}.${REQUIRED_MINOR}"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
    gum style \
        --border rounded \
        --border-foreground 1 \
        --padding "0 2" \
        "$(gum style --foreground 1 --bold "$ERRORS check(s) failed.") Run: mise install"
    exit 1
else
    gum style \
        --border rounded \
        --border-foreground 2 \
        --padding "0 2" \
        "$(gum style --foreground 2 --bold "All checks passed.")"
fi
