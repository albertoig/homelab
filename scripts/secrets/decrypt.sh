#!/bin/bash
# Decrypt per-chart secrets files for the specified environment.
# Usage: ./scripts/secrets/decrypt.sh [environment] [chart-name]   (prompts if omitted)
# Example: ./scripts/secrets/decrypt.sh prod
#          ./scripts/secrets/decrypt.sh prod grafana

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

header "Decrypting secrets for environment: $ENVIRONMENT"

decrypted=0
failed=0

if [ -n "$CHART" ]; then
    # Decrypt a single chart
    ENCRYPTED_FILE="$SECRETS_DIR/${CHART}.enc.yaml"
    SECRETS_FILE="$SECRETS_DIR/${CHART}.secrets.yaml"

    if [ ! -f "$ENCRYPTED_FILE" ]; then
        error "Encrypted file not found: $ENCRYPTED_FILE"
        exit 1
    fi

    info "Decrypting: ${CHART}.enc.yaml -> ${CHART}.secrets.yaml"
    if sops --decrypt "$ENCRYPTED_FILE" > "$SECRETS_FILE"; then
        success "Created: $(basename "$SECRETS_FILE")"
        decrypted=1
    else
        error "Failed to decrypt: $(basename "$ENCRYPTED_FILE")"
        failed=1
    fi
else
    # Decrypt all charts
    found=false
    for enc_file in "$SECRETS_DIR"/*.enc.yaml; do
        [ -f "$enc_file" ] || continue
        found=true
        chart_name=$(basename "$enc_file" .enc.yaml)
        secrets_file="$SECRETS_DIR/${chart_name}.secrets.yaml"

        info "Decrypting: ${chart_name}.enc.yaml -> ${chart_name}.secrets.yaml"
        if sops --decrypt "$enc_file" > "$secrets_file"; then
            success "Created: $(basename "$secrets_file")"
            decrypted=$((decrypted + 1))
        else
            error "Failed to decrypt: $(basename "$enc_file")"
            failed=$((failed + 1))
        fi
    done

    if [ "$found" = false ]; then
        warn "No .enc.yaml files found in $SECRETS_DIR"
        exit 0
    fi
fi

echo ""
if [ "$failed" -gt 0 ]; then
    warn "Decrypted $decrypted file(s), $failed failed."
else
    success "$ENVIRONMENT environment secrets decrypted successfully! ($decrypted file(s))"
fi
