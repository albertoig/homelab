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

if [ -n "$CHART" ]; then
    # Encrypt a single chart
    SECRETS_FILE="$SECRETS_DIR/${CHART}.secrets.yaml"
    ENCRYPTED_FILE="$SECRETS_DIR/${CHART}.enc.yaml"

    if [ ! -f "$SECRETS_FILE" ]; then
        error "Secrets file not found: $SECRETS_FILE"
        exit 1
    fi

    info "Encrypting: ${CHART}.secrets.yaml -> ${CHART}.enc.yaml"
    if sops --encrypt "$SECRETS_FILE" > "$ENCRYPTED_FILE"; then
        rm "$SECRETS_FILE"
        success "Created: $(basename "$ENCRYPTED_FILE") (plaintext removed)"
        encrypted=1
    else
        error "Failed to encrypt: $(basename "$SECRETS_FILE")"
        failed=1
    fi
else
    # Encrypt all charts
    found=false
    for secrets_file in "$SECRETS_DIR"/*.secrets.yaml; do
        [ -f "$secrets_file" ] || continue
        found=true
        chart_name=$(basename "$secrets_file" .secrets.yaml)
        enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

        info "Encrypting: ${chart_name}.secrets.yaml -> ${chart_name}.enc.yaml"
        if sops --encrypt "$secrets_file" > "$enc_file"; then
            rm "$secrets_file"
            success "Created: $(basename "$enc_file") (plaintext removed)"
            encrypted=$((encrypted + 1))
        else
            error "Failed to encrypt: $(basename "$secrets_file")"
            failed=$((failed + 1))
        fi
    done

    if [ "$found" = false ]; then
        warn "No .secrets.yaml files found in $SECRETS_DIR"
        exit 0
    fi
fi

echo ""
if [ "$failed" -gt 0 ]; then
    warn "Encrypted $encrypted file(s), $failed failed."
else
    success "$ENVIRONMENT environment secrets encrypted successfully! ($encrypted file(s))"
fi
