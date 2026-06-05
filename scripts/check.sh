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

gum style \
    --foreground 99 \
    --bold \
    --padding "1 2" \
    --margin "0 1" \
    "Requisites"
echo ""

ERRORS=0

section_result() {
    local label="$1"
    local missing=("${@:2}")
    if [ ${#missing[@]} -eq 0 ]; then
        printf "  %s  %s\n" "$(gum style --foreground 2 --bold '✓')" "$label"
    else
        printf "  %s  %s — missing: %s\n" \
            "$(gum style --foreground 1 --bold '✗')" \
            "$label" \
            "$(gum style --foreground 1 "${missing[*]}")"
        ERRORS=$(( ERRORS + ${#missing[@]} ))
    fi
}

# ── Tool manager ──────────────────────────────────────────────────────────────

MISSING=()
gum spin --spinner pulse --title "  mise" -- sleep 1
command -v mise &>/dev/null || MISSING+=("mise")
section_result "Tool manager" "${MISSING[@]}"

# ── CLI tools ─────────────────────────────────────────────────────────────────

MISSING=()
for cmd in kubectl helm helmfile sops ansible poetry gum fzf; do
    gum spin --spinner pulse --title "  $cmd" -- sleep 1
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
section_result "CLI tools" "${MISSING[@]}"

# ── Helm plugins ──────────────────────────────────────────────────────────────

MISSING=()
HELM_PLUGINS=$(helm plugin list 2>/dev/null || true)
for plugin in secrets secrets-getter secrets-post-renderer diff; do
    gum spin --spinner pulse --title "  helm-$plugin" -- sleep 1
    echo "$HELM_PLUGINS" | grep -q "^$plugin" || MISSING+=("helm-$plugin")
done
section_result "Helm plugins" "${MISSING[@]}"

# ── Kubernetes ────────────────────────────────────────────────────────────────

MISSING=()
if command -v kubectl &>/dev/null; then
    gum spin --spinner pulse --title "  kubernetes" \
        -- bash -c "kubectl cluster-info &>/dev/null" || MISSING+=("kubernetes")
else
    MISSING+=("kubectl")
fi
section_result "Kubernetes" "${MISSING[@]}"

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
        --border double \
        --border-foreground 2 \
        --padding "1 4" \
        --margin "0 1" \
        --bold \
        "$(gum style --foreground 2 --bold "✓  All checks passed. 🎉")"
fi
