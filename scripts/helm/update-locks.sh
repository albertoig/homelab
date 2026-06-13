#!/usr/bin/env bash
# Update helmfile lock files for all environments
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/colors.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELMFILE="$REPO_ROOT/helmfile.yaml.gotmpl"
ENVIRONMENTS=("dev" "prod")

header "Updating helmfile lock files"
echo ""

FAILED=()

for env in "${ENVIRONMENTS[@]}"; do
    info "Running helmfile deps for environment: ${env}"
    if helmfile -f "$HELMFILE" -e "$env" deps 2>&1; then
        success "Lock files updated for ${env}"
    else
        warn "Failed to update lock files for ${env}"
        FAILED+=("$env")
    fi
    echo ""
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    error "Failed environments: ${FAILED[*]}"
    exit 1
fi

header "All lock files updated"
