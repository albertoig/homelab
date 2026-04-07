#!/bin/bash
# Destroy helmfiles for a given environment
# Usage: ./scripts/destroy-helmfiles.sh <environment>
# Example: ./scripts/destroy-helmfiles.sh dev

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

# Validate environment directory exists
if [ ! -d "$HELMFILE_DIR/helmfile/environments/$ENVIRONMENT" ]; then
    error "Environment directory '$ENVIRONMENT' not found."
    exit 1
fi

header "Destroying environment: $ENVIRONMENT"
echo ""

warn "⚠️  WARNING: This will delete ALL PersistentVolumes and permanent storage data!"
echo ""

# Confirm destruction
read -rp "$(echo -e "${_C_YELLOW}  Are you sure you want to destroy the '${ENVIRONMENT}' environment? This is irreversible and will delete all data. [y/N] ${_C_RESET}")" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted."
    exit 0
fi

echo ""

# --- Step 1: Set Longhorn deleting-confirmation-flag ---
step 1 4 "Setting Longhorn deleting-confirmation-flag..."
if kubectl -n longhorn-system get settings.longhorn.io deleting-confirmation-flag &>/dev/null; then
    kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
        -p '{"value":"true"}' --type=merge
    success "Longhorn deletion confirmed."
else
    warn "Longhorn deleting-confirmation-flag not found, skipping."
fi
echo ""

# --- Step 2: Destroy all helmfiles ---
step 2 4 "Destroying all helmfiles..."
helmfile -f "$HELMFILE_DIR/helmfile.yaml.gotmpl" \
    --environment "$ENVIRONMENT" destroy --skip-deps 2>&1 || true
echo ""

# --- Step 3: Clean up stuck resources ---
step 3 4 "Cleaning up stuck resources..."

# Remove stuck Longhorn volumes and PVCs
info "Cleaning Longhorn volumes..."
for vol in $(kubectl get volumes.longhorn.io -n longhorn-system -o name 2>/dev/null); do
    kubectl patch "$vol" -n longhorn-system \
        -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

info "Cleaning Longhorn PVCs..."
for pvc in $(kubectl get pvc -n longhorn-system -o name 2>/dev/null); do
    kubectl patch "$pvc" -n longhorn-system \
        -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

# Remove stuck namespace finalizers
for ns in longhorn-system lb-system monitoring-system ingress-system auth-system gitops-system cert-manager-system; do
    if kubectl get namespace "$ns" &>/dev/null; then
        info "Cleaning namespace: $ns"
        kubectl patch namespace "$ns" \
            -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    fi
done

# Delete Longhorn CRDs explicitly
info "Removing Longhorn CRDs..."
for crd in $(kubectl get crd -o name 2>/dev/null | grep longhorn.io); do
    kubectl delete "$crd" --ignore-not-found 2>/dev/null || true
done

echo ""
header "Environment '$ENVIRONMENT' destroyed."
