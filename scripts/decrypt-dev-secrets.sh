#!/bin/bash
# Decrypt all .enc.yaml files in the dev environment and create .secrets.yaml files

set -e

ENVS_DIR="helmfile/environments/dev/secrets"

echo "Decrypting dev environment secrets..."

# Find all .enc.yaml files in the dev secrets directory
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

echo "Dev environment secrets decrypted successfully!"
