#!/bin/bash
# Decrypt all .enc.yaml files in the specified environment and create .secrets.yaml files
# Usage: ./scripts/decrypt-secrets.sh <environment>
# Example: ./scripts/decrypt-secrets.sh dev

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

echo "Decrypting $ENVIRONMENT environment secrets..."

# Find all .enc.yaml files in the secrets directory
for enc_file in "$ENVS_DIR"/*.enc.yaml; do
    if [ -f "$enc_file" ]; then
        # Get the filename without the .enc.yaml extension
        basename=$(basename "$enc_file" .enc.yaml)

        # Create the output filename with .secrets.yaml
        output_file="$ENVS_DIR/${basename}.secrets.yaml"

        echo "Decrypting: $enc_file -> $output_file"

        # Decrypt the file using sops
        sops --decrypt "$enc_file" > "$output_file"

        echo "Created: $output_file"
    fi
done

echo "$ENVIRONMENT environment secrets decrypted successfully!"
