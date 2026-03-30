#!/bin/bash
# Install helmfiles for a given environment
# Usage: ./scripts/install-helmfiles.sh <environment>
# Example: ./scripts/install-helmfiles.sh dev

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

HELMFILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Validate environment
if [ ! -d "$HELMFILE_DIR/helmfile/environments/$ENVIRONMENT" ]; then
    echo "Error: Environment '$ENVIRONMENT' not found."
    echo "Available environments:"
    ls "$HELMFILE_DIR/helmfile/environments/"
    exit 1
fi

# Check prerequisites
"$HELMFILE_DIR/scripts/check-requirements.sh"

echo ""

# Check Kubernetes access and version
"$HELMFILE_DIR/scripts/check-kubernetes.sh"

echo ""

echo "============================================="
echo "Installing environment: $ENVIRONMENT"
echo "============================================="
echo ""

# Confirm installation
read -rp "Do you want to install the '$ENVIRONMENT' environment? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# --- Step 1: Apply CRDs (001) ---
echo "[1/4] Applying CRDs (001)..."
helmfile -f "$HELMFILE_DIR/helmfile/001-crds.helmfile.yaml" \
    --environment "$ENVIRONMENT" sync --skip-deps
echo ""

# --- Step 2: Apply certifications (002) ---
echo "[2/4] Applying certifications (002)..."
helmfile -f "$HELMFILE_DIR/helmfile/002-certs.helmfile.yaml.gotmpl" \
    --environment "$ENVIRONMENT" sync --skip-deps
echo ""

# --- Step 3: Apply common releases ---
echo "[3/4] Applying common releases..."
helmfile -f "$HELMFILE_DIR/helmfile.yaml.gotmpl" \
    --environment "$ENVIRONMENT" sync --skip-deps
echo ""

# --- Step 4: Apply ingresses (003) ---
echo "[4/4] Applying ingresses (003)..."
helmfile -f "$HELMFILE_DIR/helmfile/003-ingresses.helmfile.yaml.gotmpl" \
    --environment "$ENVIRONMENT" sync --skip-deps
echo ""

echo "============================================="
echo "Environment '$ENVIRONMENT' installed."
echo "============================================="
