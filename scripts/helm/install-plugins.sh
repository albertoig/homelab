#!/bin/bash
# Install required Helm plugins (idempotent — skips already-installed plugins)
# Usage: ./scripts/helm/install-plugins.sh

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/colors.sh"

install_plugin() {
    local name="$1"
    local url="$2"
    shift 2

    if helm plugin list 2>/dev/null | grep -q "^$name"; then
        success "helm plugin already installed: $name"
    else
        info "Installing helm plugin: $name"
        helm plugin install "$url" "$@"
        success "Installed helm plugin: $name"
    fi
}

# Set up GPG keyring for jkroepke plugins
KEYRING_DIR="$HOME/.config/helm/keys"
KEYRING="$KEYRING_DIR/jkroepke.gpg"

if [ ! -f "$KEYRING" ]; then
    info "Setting up GPG keyring for helm-secrets..."
    mkdir -p "$KEYRING_DIR"
    chmod 700 "$KEYRING_DIR"
    curl -fsSL https://github.com/jkroepke.gpg -o "$KEYRING_DIR/jkroepke.gpg.raw"
    gpg --dearmor < "$KEYRING_DIR/jkroepke.gpg.raw" > "$KEYRING"
    chmod 600 "$KEYRING"
    rm -f "$KEYRING_DIR/jkroepke.gpg.raw"
    success "GPG keyring ready"
fi

SECRETS_VERSION="4.7.4"
BASE_URL="https://github.com/jkroepke/helm-secrets/releases/download/v${SECRETS_VERSION}"

install_plugin secrets                "${BASE_URL}/secrets-${SECRETS_VERSION}.tgz"               --keyring "$KEYRING"
install_plugin secrets-getter         "${BASE_URL}/secrets-getter-${SECRETS_VERSION}.tgz"         --keyring "$KEYRING"
install_plugin secrets-post-renderer  "${BASE_URL}/secrets-post-renderer-${SECRETS_VERSION}.tgz"  --keyring "$KEYRING"
install_plugin diff                   "https://github.com/databus23/helm-diff"                    --verify false

echo ""
success "All Helm plugins installed."
