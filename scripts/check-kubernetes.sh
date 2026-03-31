#!/bin/bash
# Check that kubectl can access the cluster and version is 1.33+
# Usage: ./scripts/check-kubernetes.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colors.sh"

ERRORS=0

info "Checking Kubernetes access..."

if ! command -v kubectl &>/dev/null; then
    error "kubectl not found"
    exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
    error "Cannot access Kubernetes cluster"
    exit 1
fi

success "Cluster accessible"

KUBE_VERSION=$(kubectl version -o json 2>/dev/null)

MAJOR=$(echo "$KUBE_VERSION" | awk '/"serverVersion"/,/\}/' | grep '"major"' | head -1 | tr -dc '0-9')
MINOR=$(echo "$KUBE_VERSION" | awk '/"serverVersion"/,/\}/' | grep '"minor"' | head -1 | tr -dc '0-9')

if [ -z "$MAJOR" ] || [ -z "$MINOR" ]; then
    error "Could not determine Kubernetes version"
    exit 1
fi

REQUIRED_MAJOR=1
REQUIRED_MINOR=33

if [ "$MAJOR" -gt "$REQUIRED_MAJOR" ] || { [ "$MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$MINOR" -ge "$REQUIRED_MINOR" ]; }; then
    success "Kubernetes v${MAJOR}.${MINOR} (>= ${REQUIRED_MAJOR}.${REQUIRED_MINOR})"
else
    error "Kubernetes v${MAJOR}.${MINOR}, requires >= ${REQUIRED_MAJOR}.${REQUIRED_MINOR}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ "$ERRORS" -gt 0 ]; then
    error "Kubernetes version check failed. Upgrade your cluster."
    exit 1
fi

success "Kubernetes check passed."
exit 0
