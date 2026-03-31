#!/bin/bash
# Encrypt per-chart secrets files for the specified environment.
# Usage: ./scripts/sops-encrypt-secrets.sh <environment> [chart-name]
# Example: ./scripts/sops-encrypt-secrets.sh prod
#          ./scripts/sops-encrypt-secrets.sh prod grafana

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colors.sh"

ENVIRONMENT="${1:-}"
CHART="${2:-}"

if [ -z "$ENVIRONMENT" ]; then
    error "Usage: $0 <environment> [chart-name]"
    info "Available environments: dev, prod"
    exit 1
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    error "Invalid environment '$ENVIRONMENT'."
    info "Available environments: dev, prod"
    exit 1
fi

SECRETS_DIR="helmfile/environments/$ENVIRONMENT/secrets"

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
        success "Created: $(basename "$ENCRYPTED_FILE")"
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
            success "Created: $(basename "$enc_file")"
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
