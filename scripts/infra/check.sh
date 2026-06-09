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

gum style \
    --foreground 99 \
    --bold \
    --padding "1 2" \
    --margin "0 1" \
    "Requisites"
echo ""

ERRORS=0

# Print a persistent tick/cross line and store the result for box rendering
TOOLS_BOX_LINES=""

section_result() {
    local label="$1"
    local missing=("${@:2}")
    local line
    if [ ${#missing[@]} -eq 0 ]; then
        printf "  %s  %s\n" "$(gum style --foreground 2 --bold '✓')" "$label"
        line="$(printf "  %s  %s" "$(gum style --foreground 2 --bold '✓')" "$label")"
    else
        printf "  %s  %s — missing: %s\n" \
            "$(gum style --foreground 1 --bold '✗')" \
            "$label" \
            "$(gum style --foreground 1 "${missing[*]}")"
        line="$(printf "  %s  %s" "$(gum style --foreground 1 --bold '✗')" "$label")"
        ERRORS=$(( ERRORS + ${#missing[@]} ))
    fi
    TOOLS_BOX_LINES="${TOOLS_BOX_LINES:+${TOOLS_BOX_LINES}$'\n'}${line}"
}

# ── Tool manager ──────────────────────────────────────────────────────────────

MISSING=()
gum spin --spinner pulse --padding="0 0 0 2" --title "  mise" -- sleep 0.9
command -v mise &>/dev/null || MISSING+=("mise")
section_result "Tool manager" "${MISSING[@]}"

# ── CLI tools ─────────────────────────────────────────────────────────────────

MISSING=()
for cmd in kubectl helm helmfile sops ansible poetry gum fzf; do
    gum spin --spinner pulse --padding="0 0 0 2" --title "  $cmd" -- sleep 0.9
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
section_result "CLI tools" "${MISSING[@]}"

# ── Helm plugins ──────────────────────────────────────────────────────────────

MISSING=()
HELM_PLUGINS=$(helm plugin list 2>/dev/null || true)
for plugin in secrets secrets-getter secrets-post-renderer diff; do
    gum spin --spinner pulse --padding="0 0 0 2" --title "  helm-$plugin" -- sleep 0.9
    echo "$HELM_PLUGINS" | grep -q "^$plugin" || MISSING+=("helm-$plugin")
done
section_result "Helm plugins" "${MISSING[@]}"

# ── Kubernetes ────────────────────────────────────────────────────────────────

MISSING=()
if command -v kubectl &>/dev/null; then
    gum spin --spinner pulse --padding="0 0 0 2" --title "  kubernetes" \
        -- bash -c "kubectl cluster-info &>/dev/null" || MISSING+=("kubernetes")
else
    MISSING+=("kubectl")
fi
section_result "Kubernetes" "${MISSING[@]}"

# ── Secrets spinners ──────────────────────────────────────────────────────────

echo ""
TEMPLATES_DIR="$ROOT_DIR/helmfile/secret-templates"
SECRETS_BOX_LINES=""

for template in "$TEMPLATES_DIR"/*.template.yaml; do
    [ -f "$template" ] || continue
    chart=$(basename "$template" .template.yaml)
    for env in "${ENVS[@]}"; do
        enc="$ROOT_DIR/helmfile/environments/$env/secrets/${chart}.enc.yaml"
        gum spin --spinner pulse --padding="0 0 0 2" --title "  $env / $chart" -- sleep 0.5
        if [ -f "$enc" ]; then
            line="$(printf "  %s  %s" "$(gum style --foreground 2 --bold '✓')" "$env / $chart")"
        else
            line="$(printf "  %s  %s" "$(gum style --foreground 1 --bold '✗')" "$env / $chart")"
            ERRORS=$((ERRORS + 1))
        fi
        SECRETS_BOX_LINES="${SECRETS_BOX_LINES:+${SECRETS_BOX_LINES}$'\n'}${line}"
    done
done

# ── Boxes ─────────────────────────────────────────────────────────────────────

echo ""

TOOLS_BOX=$(gum style \
    --border rounded \
    --border-foreground 99 \
    --padding "1 2" \
    "$(gum style --foreground 99 --bold 'Tools')" \
    "" \
    "$TOOLS_BOX_LINES")

SECRETS_BOX=$(gum style \
    --border rounded \
    --border-foreground 99 \
    --padding "1 2" \
    "$(gum style --foreground 99 --bold 'Secrets')" \
    "" \
    "$SECRETS_BOX_LINES")

gum join --horizontal "$TOOLS_BOX" "   " "$SECRETS_BOX"
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
