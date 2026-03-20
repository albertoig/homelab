#!/bin/bash
# Decrypt all .enc.yaml files in the prod environment and create .secrets.yaml files

set -e

ENVS_DIR="helmfile/environments/prod/secrets"

echo "Decrypting prod environment secrets..."

# Find all .enc.yaml files in the prod secrets directory
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

echo "Prod environment secrets decrypted successfully!"
