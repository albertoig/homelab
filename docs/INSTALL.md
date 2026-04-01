# Installation Guide

Step-by-step guide to set up the homelab from scratch.

## Prerequisites

### CLI tools

Install the following tools:

| Tool | Purpose | Install |
|------|---------|---------|
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI | Required |
| [helm](https://helm.sh/docs/intro/install/) | Kubernetes package manager | Required |
| [helmfile](https://helmfile.readthedocs.io/en/latest/#installation) | Helm releases management | Required |
| [sops](https://github.com/mozilla/sops#installation) | Secrets encryption | Required |
| [ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) | Cluster provisioning | Required |

Verify all tools are installed:

```bash
./scripts/check-requirements.sh
```

### Helm plugins

```bash
# Create a secure directory for GPG keys
mkdir -p ~/.config/helm/keys
chmod 700 ~/.config/helm/keys

# Import GPG key for helm-secrets plugin
curl -fsSL https://github.com/jkroepke.gpg -o ~/.config/helm/keys/jkroepke.gpg.raw
gpg --dearmor < ~/.config/helm/keys/jkroepke.gpg.raw > ~/.config/helm/keys/jkroepke.gpg
chmod 600 ~/.config/helm/keys/jkroepke.gpg

# Install required plugins
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-getter-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-post-renderer-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# helm-diff has no signed release; --verify false skips GPG verification
helm plugin install https://github.com/databus23/helm-diff --verify false

rm ~/.config/helm/keys/jkroepke.gpg.raw

# Verify
helm plugin list
# Should list: secrets, secrets-getter, secrets-post-renderer, diff
```

### Accounts and credentials

| Credential | Purpose | Where to obtain |
|------------|---------|-----------------|
| Cloudflare API token | DNS management for cert-manager and external-dns | [Cloudflare Dashboard](https://dash.cloudflare.com/) → API Tokens (needs `Zone:DNS:Edit` + `Zone:Zone:Read`) |
| Cloudflare account email | Cloudflare API authentication | Your Cloudflare account |
| Let's Encrypt email | ACME certificate notifications | Any email you control |
| SMTP credentials | Authentik email delivery | Any SMTP provider (Gmail, ProtonMail, etc.) |
| Slack webhook URL | Alertmanager notifications | [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks) |
| PGP key | SOPS encryption/decryption | Your existing PGP key (fingerprint in `.sops.yaml`) |
| SSH key | Ansible provisioning | `~/.ssh/homelab` |

---

## Setup

### 1. Configure environment

Copy the config template and customize:

```bash
# Create environment directory
mkdir -p helmfile/environments/<env>

# Copy config template
cp helmfile/config.template.yaml helmfile/environments/<env>/config.yaml

# Edit with your values
vim helmfile/environments/<env>/config.yaml
```

At minimum, set:
- `general.root_dns` — your domain (e.g., `example.com`)
- `metallb.ipPool` — IP range for your network (e.g., `192.168.1.100-192.168.1.110`)

See [CONFIG.md](./CONFIG.md) for all available options.

### 2. Initialize secrets

```bash
./scripts/init-secrets.sh <env>
```

This prompts interactively for each secret value (passwords, API keys, tokens) and auto-encrypts them with SOPS.

See [SECRETS.md](./SECRETS.md) for a full reference of required secrets.

### 3. Provision the cluster

```bash
cd metal/k3s
./run.sh
```

This runs Ansible to provision K3s on bare-metal nodes defined in the inventory.

### 4. Deploy services

```bash
./scripts/install-helmfiles.sh <env>
```

This runs 4 steps in order:
1. Apply CRDs (prometheus-operator)
2. Apply certificates (cert-manager, cert-manager-config, external-dns)
3. Apply common releases (monitoring, storage, networking, auth, gitops)
4. Apply ingresses (external-facing ingress resources)

### 5. Verify

```bash
kubectl get pods -A
```

---

## Environment management

### Deploy a specific environment

```bash
./scripts/install-helmfiles.sh dev
./scripts/install-helmfiles.sh prod
```

### Destroy an environment

```bash
./scripts/destroy-helmfiles.sh <env>
```

This tears down all releases in reverse dependency order and cleans up stuck resources.

### Update secrets

```bash
# Interactive re-initialization (overwrites existing)
./scripts/init-secrets.sh <env>

# Or manual edit workflow:
./scripts/sops-decrypt-secrets.sh <env> [chart]
vim helmfile/environments/<env>/secrets/<chart>.secrets.yaml
./scripts/sops-encrypt-secrets.sh <env> [chart]
```

### Preview changes without applying

```bash
helmfile -e <env> diff
```

---

## Troubleshooting

### Helmfile template fails with "no such file or directory"

Ensure `helmfile/environments/<env>/config.yaml` exists. Copy from `helmfile/config.template.yaml` if missing.

### Secrets decryption fails

Verify your PGP key is available:
```bash
gpg --list-keys
```

Ensure the key fingerprint matches `.sops.yaml`.

### Pods stuck in Pending

Check if MetalLB assigned an IP:
```bash
kubectl get svc -A | grep LoadBalancer
```

Verify the `metallb.ipPool` in your config is correct for your network.

---

## Related

- **Configuration:** [CONFIG.md](./CONFIG.md) — config system reference
- **Secrets:** [SECRETS.md](./SECRETS.md) — secrets reference
- **Scripts:** [SCRIPTS.md](./SCRIPTS.md) — automation scripts
