#!/bin/bash
# Decrypt the centralized secrets file for the specified environment
# Usage: ./scripts/sops-decrypt-secrets.sh <environment>
# Example: ./scripts/sops-decrypt-secrets.sh dev

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

ENCRYPTED_FILE="helmfile/environments/$ENVIRONMENT/secrets.enc.yaml"
SECRETS_FILE="helmfile/environments/$ENVIRONMENT/secrets.yaml"

if [ ! -f "$ENCRYPTED_FILE" ]; then
    error "Encrypted secrets file not found: $ENCRYPTED_FILE"
    exit 1
fi

info "Decrypting $ENVIRONMENT environment secrets..."
info "Decrypting: $ENCRYPTED_FILE -> $SECRETS_FILE"

sops --decrypt "$ENCRYPTED_FILE" > "$SECRETS_FILE"

success "Created: $SECRETS_FILE"
success "$ENVIRONMENT environment secrets decrypted successfully!"
