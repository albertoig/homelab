#!/bin/bash
# Encrypt per-chart secrets files for the specified environment.
# Usage: ./scripts/secrets/encrypt.sh [environment] [chart-name]   (prompts if omitted)
# Example: ./scripts/secrets/encrypt.sh prod
#          ./scripts/secrets/encrypt.sh prod grafana

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

# Environment selector (arg, ENV var, or prompt); the chart stays positional 2.
source "$SCRIPT_DIR/../lib/env.sh" "${1:-}"
ENVIRONMENT="$ENV"
CHART="${2:-}"

clear
show_header
show_subheader "$ENV"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETS_DIR="$REPO_ROOT/helmfile/environments/$ENVIRONMENT/secrets"

if [ ! -d "$SECRETS_DIR" ]; then
    error "Secrets directory not found: $SECRETS_DIR"
    exit 1
fi

header "Encrypting secrets for environment: $ENVIRONMENT"

encrypted=0
failed=0
unchanged=0

# Encrypt $1 (.secrets.yaml) -> $2 (.enc.yaml), then remove the plaintext.
# Idempotent: if the existing .enc.yaml already decrypts to the same content
# (compared semantically via yq, ignoring comments/formatting), skip the
# re-encrypt so SOPS does not churn the IV/MAC on every run. Returns:
#   0 = re-encrypted, 2 = unchanged (kept), 1 = failed.
encrypt_one() {
    local secrets_file="$1" enc_file="$2"
    if [ -f "$enc_file" ] && \
       diff -q <(sops --decrypt "$enc_file" 2>/dev/null | yq -P '... comments=""') \
               <(yq -P '... comments=""' "$secrets_file") >/dev/null 2>&1; then
        rm -f "$secrets_file"
        success "$(basename "$enc_file") unchanged — kept (plaintext removed)"
        return 2
    fi
    if sops --encrypt "$secrets_file" > "$enc_file"; then
        rm -f "$secrets_file"
        success "Created: $(basename "$enc_file") (plaintext removed)"
        return 0
    fi
    error "Failed to encrypt: $(basename "$secrets_file")"
    return 1
}

if [ -n "$CHART" ]; then
    # Encrypt a single chart
    SECRETS_FILE="$SECRETS_DIR/${CHART}.secrets.yaml"
    ENCRYPTED_FILE="$SECRETS_DIR/${CHART}.enc.yaml"

    if [ ! -f "$SECRETS_FILE" ]; then
        error "Secrets file not found: $SECRETS_FILE"
        exit 1
    fi

    info "Encrypting: ${CHART}.secrets.yaml -> ${CHART}.enc.yaml"
    rc=0; encrypt_one "$SECRETS_FILE" "$ENCRYPTED_FILE" || rc=$?
    case "$rc" in
        0) encrypted=1 ;;
        2) unchanged=1 ;;
        *) failed=1 ;;
    esac
else
    # Encrypt all charts
    found=false
    for secrets_file in "$SECRETS_DIR"/*.secrets.yaml; do
        [ -f "$secrets_file" ] || continue
        found=true
        chart_name=$(basename "$secrets_file" .secrets.yaml)
        enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

        info "Encrypting: ${chart_name}.secrets.yaml -> ${chart_name}.enc.yaml"
        rc=0; encrypt_one "$secrets_file" "$enc_file" || rc=$?
        case "$rc" in
            0) encrypted=$((encrypted + 1)) ;;
            2) unchanged=$((unchanged + 1)) ;;
            *) failed=$((failed + 1)) ;;
        esac
    done

    if [ "$found" = false ]; then
        warn "No .secrets.yaml files found in $SECRETS_DIR"
        exit 0
    fi
fi

echo ""
if [ "$failed" -gt 0 ]; then
    warn "Encrypted $encrypted, kept $unchanged unchanged, $failed failed."
else
    success "$ENVIRONMENT secrets: $encrypted re-encrypted, $unchanged unchanged."
fi
