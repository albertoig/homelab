#!/bin/bash
# Check that all prerequisites are installed before running helmfile operations
# Usage: ./scripts/check-requirements.sh

ERRORS=0

check_command() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        echo "  [OK] $cmd ($(command -v "$cmd"))"
    else
        echo "  [MISSING] $cmd"
        ERRORS=$((ERRORS + 1))
    fi
}

check_helm_plugin() {
    local plugin="$1"
    if helm plugin list 2>/dev/null | grep -q "^$plugin"; then
        echo "  [OK] helm plugin: $plugin"
    else
        echo "  [MISSING] helm plugin: $plugin"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "Checking prerequisites..."
echo ""

echo "CLI tools:"
check_command kubectl
check_command terraform
check_command helm
check_command helmfile
check_command sops
check_command ansible

echo ""
echo "Helm plugins:"
check_helm_plugin secrets
check_helm_plugin secrets-getter
check_helm_plugin secrets-post-renderer
check_helm_plugin diff

echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo "Missing $ERRORS requirement(s). Install them before proceeding."
    echo "See README.md 'Prerequisites' and 'Required Helm Plugins' sections."
    exit 1
fi

echo "All requirements met."
exit 0
