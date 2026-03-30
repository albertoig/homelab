#!/bin/bash
# Encrypt all .secrets.yaml files in the specified environment and update .enc.yaml files
# Usage: ./scripts/sops-encrypt-secrets.sh <environment>
# Example: ./scripts/sops-encrypt-secrets.sh dev

set -e

ENVIRONMENT="${1:-}"

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    echo "Available environments: dev, prod"
    exit 1
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo "Error: Invalid environment '$ENVIRONMENT'."
    echo "Available environments: dev, prod"
    exit 1
fi

ENVS_DIR="helmfile/environments/$ENVIRONMENT/secrets"

echo "Encrypting $ENVIRONMENT environment secrets..."

# Find all .secrets.yaml files in the secrets directory
for secrets_file in "$ENVS_DIR"/*.secrets.yaml; do
    if [ -f "$secrets_file" ]; then
        # Get the filename without the .secrets.yaml extension
        basename=$(basename "$secrets_file" .secrets.yaml)

        # Create the output filename with .enc.yaml
        output_file="$ENVS_DIR/${basename}.enc.yaml"

        echo "Encrypting: $secrets_file -> $output_file"

        # Encrypt the file using sops
        sops --encrypt "$secrets_file" > "$output_file"

        echo "Created: $output_file"
    fi
done

echo "$ENVIRONMENT environment secrets encrypted successfully!"
