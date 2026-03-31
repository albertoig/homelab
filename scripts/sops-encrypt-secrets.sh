#!/bin/bash
# Encrypt the centralized secrets file for the specified environment
# Usage: ./scripts/sops-encrypt-secrets.sh <environment>
# Example: ./scripts/sops-encrypt-secrets.sh dev

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colors.sh"

ENVIRONMENT="${1:-}"

if [ -z "$ENVIRONMENT" ]; then
    error "Usage: $0 <environment>"
    info "Available environments: dev, prod"
    exit 1
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    error "Invalid environment '$ENVIRONMENT'."
    info "Available environments: dev, prod"
    exit 1
fi

SECRETS_FILE="helmfile/environments/$ENVIRONMENT/secrets.yaml"
ENCRYPTED_FILE="helmfile/environments/$ENVIRONMENT/secrets.enc.yaml"

if [ ! -f "$SECRETS_FILE" ]; then
    error "Secrets file not found: $SECRETS_FILE"
    exit 1
fi

info "Encrypting $ENVIRONMENT environment secrets..."
info "Encrypting: $SECRETS_FILE -> $ENCRYPTED_FILE"

sops --encrypt "$SECRETS_FILE" > "$ENCRYPTED_FILE"

success "Created: $ENCRYPTED_FILE"
success "$ENVIRONMENT environment secrets encrypted successfully!"
