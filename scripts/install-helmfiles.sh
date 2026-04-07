#!/bin/bash
# Install helmfiles for a given environment
# Usage: ./scripts/install-helmfiles.sh <environment>
# Example: ./scripts/install-helmfiles.sh dev

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

HELMFILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Validate environment
if [ ! -d "$HELMFILE_DIR/helmfile/environments/$ENVIRONMENT" ]; then
    error "Environment '$ENVIRONMENT' not found."
    info "Available environments:"
    ls "$HELMFILE_DIR/helmfile/environments/"
    exit 1
fi

# Check prerequisites
"$HELMFILE_DIR/scripts/check-requirements.sh"

echo ""

# Check Kubernetes access and version
"$HELMFILE_DIR/scripts/check-kubernetes.sh"

echo ""

header "Installing environment: $ENVIRONMENT"
echo ""

# Confirm installation
read -rp "$(echo -e "${_C_YELLOW}  Do you want to install the '${ENVIRONMENT}' environment? [y/N] ${_C_RESET}")" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted."
    exit 0
fi

echo ""

# --- Step 1: Apply all releases ---
step 1 1 "Applying all releases..."
helmfile -f "$HELMFILE_DIR/helmfile.yaml.gotmpl" \
    --environment "$ENVIRONMENT" sync --skip-deps
echo ""

header "Environment '$ENVIRONMENT' installed."
