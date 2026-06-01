# Installation Guide

Step-by-step guide to set up the homelab from scratch.

## Prerequisites

### CLI tools

All required tools are declared in `.mise.toml`. Install [mise](https://mise.jdx.dev/) once, then let it handle everything else:

```bash
# Install mise (once, globally)
curl https://mise.run | sh

# Activate mise in your shell — add to ~/.bashrc or ~/.zshrc
echo 'eval "$(mise activate bash)"' >> ~/.bashrc   # bash
echo 'eval "$(mise activate zsh)"'  >> ~/.zshrc    # zsh

# Reload your shell
source ~/.bashrc  # or ~/.zshrc

# Install all tools + helm plugins + git hooks + terraform providers
mise run setup

# Verify
mise run check
```

Pinned versions are in `.mise.toml`. To upgrade a tool, change its version there and re-run `mise install`.

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
mise run secrets:init <env>
```

This prompts interactively for each secret value (passwords, API keys, tokens) and auto-encrypts them with SOPS.

See [SECRETS.md](./SECRETS.md) for a full reference of required secrets.

### 3. Provision the cluster

```bash
mise run provision
```

This runs Ansible to provision K3s on bare-metal nodes defined in the inventory.

### 4. Deploy services

```bash
mise run install <env>
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
mise run install dev
mise run install prod
```

### Destroy an environment

```bash
mise run destroy <env>
```

This tears down all releases in reverse dependency order and cleans up stuck resources.

### Update secrets

```bash
# Interactive re-initialization (overwrites existing)
mise run secrets:init <env>

# Or manual edit workflow:
mise run secrets:decrypt <env> <chart>
vim helmfile/environments/<env>/secrets/<chart>.secrets.yaml
mise run secrets:encrypt <env> <chart>
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

### Emergency access — Authentik is unavailable

Both Grafana and ArgoCD are configured for SSO-only access. If Authentik is unreachable, use the procedures below to regain access without SSO.

#### Grafana

Grafana auto-redirects to Authentik on every login attempt. To bypass this and show the local login form, navigate to:

```
https://grafana.internal.<root_dns>/login?disableAutoLogin
```

No local admin user exists by default (`disable_initial_admin_creation: true`). Create one via the Grafana CLI without redeploying:

```bash
kubectl exec -n monitoring-system deploy/grafana -- \
  grafana-cli admin reset-admin-password <new-password>
```

Then log in at the URL above with username `admin` and the password you set. Revert the password or disable the admin account once Authentik is restored.

#### ArgoCD

ArgoCD's built-in admin account is disabled by default (`configs.admin.enabled: false`). To re-enable it temporarily, add an environment values override:

```yaml
# helmfile/environments/<env>/values/argocd.yaml.gotmpl
configs:
  admin:
    enabled: true
```

Redeploy ArgoCD:

```bash
mise run install <env>
```

Retrieve the admin password:

```bash
kubectl get secret -n gitops-system argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Remove the override and redeploy again once Authentik is restored.

---

## Related

- **Configuration:** [CONFIG.md](./CONFIG.md) — config system reference
- **Secrets:** [SECRETS.md](./SECRETS.md) — secrets reference
- **Scripts:** [SCRIPTS.md](./SCRIPTS.md) — automation scripts
