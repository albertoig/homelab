#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK="${1:-site}"
INVENTORY="${SCRIPT_DIR}/inventory.yml"
ENCRYPTED_INVENTORY="${SCRIPT_DIR}/inventory.sops.yml"
SECRETS_FILE="${SCRIPT_DIR}/secrets.yml"
SSH_KEY="${HOME}/.ssh/homelab"

# ─── Check SSH Key Exists ─────────────────────────────────────────────────────

if [[ ! -f "$SSH_KEY" ]]; then
  echo "Error: SSH key not found at ${SSH_KEY}"
  echo "Generate one with:"
  echo "  ssh-keygen -t ed25519 -C \"homelab\" -f ~/.ssh/homelab"
  echo "Then copy it to each node:"
  echo "  ssh-copy-id -i ~/.ssh/homelab.pub ubuntu@YOUR_NODE_IP"
  exit 1
fi

# ─── Load SSH Key into Agent ──────────────────────────────────────────────────

if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  echo "Starting SSH agent..."
  eval "$(ssh-agent -s)"
fi

if ! ssh-add -l | grep -q "$SSH_KEY"; then
  echo "Adding SSH key to agent..."
  ssh-add "$SSH_KEY"
fi

# ─── Decrypt Inventory ────────────────────────────────────────────────────────

if [[ ! -f "$ENCRYPTED_INVENTORY" ]]; then
  echo "Error: inventory.sops.yml not found at ${ENCRYPTED_INVENTORY}"
  echo "Create and encrypt one with:"
  echo "  cp metal/k3s/inventory.example.yml metal/k3s/inventory.sops.yml"
  echo "  sops --encrypt --in-place metal/k3s/inventory.sops.yml"
  exit 1
fi

echo "Decrypting inventory..."
sops --decrypt "$ENCRYPTED_INVENTORY" > "$INVENTORY"

trap 'echo "Cleaning up decrypted inventory..."; rm -f "$INVENTORY"' EXIT

# ─── cd into script dir so ansible.cfg is picked up ──────────────────────────

cd "$SCRIPT_DIR"

# ─── Install Collections ──────────────────────────────────────────────────────

echo "Installing Ansible collections..."
ansible-galaxy collection install -r "${SCRIPT_DIR}/requirements.yml"

# ─── Validate Inventory ───────────────────────────────────────────────────────

echo "Validating inventory..."
ansible-inventory -i "$INVENTORY" --list > /dev/null

# ─── Connectivity Check ───────────────────────────────────────────────────────

echo "Checking connectivity to all nodes..."
ansible all -i "$INVENTORY" -m ping || {
  echo "Error: Could not reach one or more nodes."
  exit 1
}

# ─── Run Playbook ─────────────────────────────────────────────────────────────

echo "Running playbook: $PLAYBOOK"

# Use vault secrets file if it exists
if [[ -f "$SECRETS_FILE" ]]; then
  echo "Found secrets.yml, prompting for vault password..."
  ansible-playbook "k3s.orchestration.${PLAYBOOK}" \
    -i "$INVENTORY" \
    -e "@${SECRETS_FILE}" \
    --ask-vault-pass \
    -v
else
  ansible-playbook "k3s.orchestration.${PLAYBOOK}" \
    -i "$INVENTORY" \
    -v
fi
