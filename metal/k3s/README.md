# K3s Cluster Provisioning

This directory contains everything needed to provision a lightweight Kubernetes
cluster using [k3s](https://k3s.io) via Ansible on bare metal machines.

It uses the official [k3s-ansible](https://github.com/k3s-io/k3s-ansible)
collection pinned to a specific commit for reproducibility.

## Requirements

Install these on your **local machine** before anything else.

```bash
# Ansible
pip install ansible

# SOPS - for encrypting secrets
brew install sops          # macOS
sudo apt install sops      # Debian/Ubuntu

# age - encryption backend for SOPS
brew install age           # macOS
sudo apt install age       # Debian/Ubuntu
```

---

## Part 1 - Prepare Your Machines

Do this once per machine before running any Ansible commands.

### 1.1 - Install an OS

Install Ubuntu Server (or Debian) on each machine.
During installation make sure to:

- Create a user (e.g. `ubuntu`)
- Enable SSH server
- Note down the IP address of each machine

### 1.2 - Configure Static IPs

Your nodes need static IPs so they do not change between reboots.
Do this on **each node**.

```bash
# SSH into the node
ssh ubuntu@YOUR_NODE_IP

# Find your network interface name
ip link show
# Look for something like: eth0, enp3s0, eno1

# Edit netplan config
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp3s0:                        # replace with your interface name
      dhcp4: false
      addresses:
        - 192.168.1.10/24          # replace with your desired static IP
      routes:
        - to: default
          via: 192.168.1.1         # replace with your router/gateway IP
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```

```bash
# Apply the config
sudo netplan apply

# Verify the IP stuck
ip addr show
```

### 1.3 - Configure Passwordless Sudo

Ansible needs root access to install software on your nodes.
Run this on **each node**.

```bash
# SSH into the node
ssh ubuntu@YOUR_NODE_IP

# Replace ubuntu with your actual username if different
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu

# Verify it works - should print root with no password prompt
sudo whoami
```

---

## Part 2 - Set Up SSH Keys

Do this on your **local machine**.

### 2.1 - Generate a Dedicated Homelab SSH Key

```bash
# Generate a new key pair specifically for your homelab
# Do not reuse your GitHub or other existing keys
ssh-keygen -t ed25519 -C "homelab" -f ~/.ssh/homelab

# This creates:
# ~/.ssh/homelab      ← private key, never share or commit this
# ~/.ssh/homelab.pub  ← public key, goes on the nodes
```

### 2.2 - Copy the Public Key to Each Node

```bash
# You will be prompted for the node user password once per node
ssh-copy-id -i ~/.ssh/homelab.pub ubuntu@192.168.1.10   # server
ssh-copy-id -i ~/.ssh/homelab.pub ubuntu@192.168.1.11   # agent 1
ssh-copy-id -i ~/.ssh/homelab.pub ubuntu@192.168.1.12   # agent 2

# Test passwordless login works - should log in with no password prompt
ssh -i ~/.ssh/homelab ubuntu@192.168.1.10
```

### 2.3 - Harden SSH (Disable Password Login)

Now that your key is working, disable password authentication on each node
so only SSH key login is allowed.

```bash
# SSH into each node
ssh -i ~/.ssh/homelab ubuntu@YOUR_NODE_IP

sudo nano /etc/ssh/sshd_config
```

Change or add these lines:

```ini
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
```

```bash
# Apply changes
sudo systemctl restart sshd
```

> ⚠️ Verify your key login works in a second terminal before closing
> your current session or you will lock yourself out.

---

## Part 3 - Configure the Cluster

### 3.1 - Set Up SOPS Encryption

Your inventory contains sensitive values like the cluster token.
SOPS encrypts it so you can safely commit it to a public repository.

```bash
# Generate an age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# The output shows your public key, copy it:
# Public key: age1abc123...

# Open .sops.yaml at the root of the repo and paste your public key
nano .sops.yaml
```

### 3.2 - Create Your Inventory

```bash
# Copy the example inventory
cp metal/k3s/inventory.example.yml metal/k3s/inventory.sops.yml

# Edit it with your real values
nano metal/k3s/inventory.sops.yml
```

Fill in the following values:

| Field | Description | Example |
|-------|-------------|---------|
| `YOUR_SERVER_IP` | IP of your server/master node | `192.168.1.10` |
| `YOUR_AGENT_IP` | IP of each agent/worker node | `192.168.1.11` |
| `YOUR_USERNAME` | Linux user on the nodes | `ubuntu` |
| `k3s_version` | k3s version to install | `v1.32.0+k3s1` |
| `token` | Cluster join secret | output of `openssl rand -base64 64` |

Generate your token:

```bash
openssl rand -base64 64
```

### 3.3 - Encrypt Your Inventory

```bash
# Encrypt the inventory - this is now safe to commit
sops --encrypt --in-place metal/k3s/inventory.sops.yml

# Commit it
git add metal/k3s/inventory.sops.yml
git commit -m "feat(metal/k3s): add encrypted cluster inventory"
```

To edit it later:

```bash
# Opens your editor, re-encrypts automatically on save
sops metal/k3s/inventory.sops.yml
```

---

## Part 4 - Deploy the Cluster

```bash
# Make the script executable (first time only)
chmod +x metal/k3s/run.sh

# Deploy the cluster
./metal/k3s/run.sh site

# The script will:
# 1. Check your SSH key exists
# 2. Load it into the SSH agent
# 3. Decrypt inventory.sops.yml
# 4. Install Ansible collections
# 5. Validate the inventory
# 6. Ping all nodes to verify connectivity
# 7. Run the k3s-ansible playbook
# 8. Clean up the plaintext inventory on exit
```

### Verify the Cluster

```bash
# kubeconfig is copied to your machine automatically by the playbook
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES                  AGE   VERSION
# 192.168.1.10   Ready    control-plane,master   1m    v1.32.0+k3s1
# 192.168.1.11   Ready    <none>                 1m    v1.32.0+k3s1
```

---

## Reset / Uninstall

```bash
# Completely removes k3s from all nodes
./metal/k3s/run.sh reset
```

---

## Troubleshooting

### `No inventory was parsed`
Your inventory YAML structure is wrong. Hosts must be mappings not lists:
```yaml
# ❌ Wrong
hosts:
  - 192.168.1.10

# ✅ Correct
hosts:
  192.168.1.10:
```

### `Missing sudo password`
Passwordless sudo is not configured on the node. See section 1.3.

### `Permission denied (publickey)`
SSH key is not copied to the node. See section 2.2.

### `No config file found`
Always run via `./metal/k3s/run.sh` and not directly with `ansible-playbook`
from a different directory. The script `cd`s into the correct directory
so `ansible.cfg` is picked up automatically.

### `Could not reach one or more nodes`
- Check the node is powered on: `ping YOUR_NODE_IP`
- Check SSH works manually: `ssh -i ~/.ssh/homelab ubuntu@YOUR_NODE_IP`
- Check the IP in your inventory matches the actual node IP
