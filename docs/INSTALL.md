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
| Cloudflare DNS token | DNS management for cert-manager and external-dns | See [Cloudflare tokens](#cloudflare-tokens) below |
| Cloudflare Terraform token | R2 bucket provisioning via Terraform | See [Cloudflare tokens](#cloudflare-tokens) below |
| Cloudflare R2 token | Velero backup read/write access | See [Cloudflare tokens](#cloudflare-tokens) below |
| Cloudflare account email | Cloudflare API authentication | Your Cloudflare account |
| Let's Encrypt email | ACME certificate notifications | Any email you control |
| SMTP credentials | Authentik email delivery | Any SMTP provider (Gmail, ProtonMail, etc.) |
| Slack webhook URL | Alertmanager notifications | [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks) |
| PGP key | SOPS encryption/decryption | Your existing PGP key (fingerprint in `.sops.yaml`) |
| SSH key | Ansible provisioning | `~/.ssh/homelab` |

### Cloudflare tokens

Three separate Cloudflare tokens are required. Each has a different permission scope and is stored in a different place.

---

#### Token 1 — DNS (cert-manager + external-dns)

**Used by:** cert-manager (DNS-01 ACME challenges to issue TLS certificates) and external-dns (creating and updating DNS records automatically).

**Type:** Cloudflare API Token — create at [Cloudflare Dashboard](https://dash.cloudflare.com/) → My Profile → API Tokens → Create Token.

**Permissions:**

| Resource | Permission |
|----------|------------|
| Zone > DNS | Edit |
| Zone > Zone | Read |

Scope both permissions to the specific zone (domain) you are using.

**Where it goes:** `helmfile/environments/<env>/secrets/cert-manager-config.enc.yaml` → `secret.apiKey`

Set it during `mise run secrets:init <env>` when prompted for the cert-manager-config secret.

---

#### Token 2 — Terraform (R2 bucket provisioning)

**Used by:** Terraform to create and manage the Cloudflare R2 bucket that stores Velero backups. Only needed when running `mise run tf:apply` or `mise run tf:destroy`.

**Type:** Cloudflare API Token — create at [Cloudflare Dashboard](https://dash.cloudflare.com/) → My Profile → API Tokens → Create Token.

**Permissions:**

| Resource | Permission |
|----------|------------|
| Account > R2 Storage | Edit |

Scope to your account.

**Where it goes:** `.mise.local.toml` (gitignored, loaded automatically by mise):

```bash
cp .mise.local.toml.example .mise.local.toml
# then fill in CLOUDFLARE_API_TOKEN
```

This is the recommended approach. Alternatively, export it manually before running Terraform:

```bash
export CLOUDFLARE_API_TOKEN="your-token-here"
mise run tf:apply
```

This token is never stored in the repository.

---

#### Token 3 — R2 API token (Velero backups)

**Used by:** Velero at runtime to read and write backup data to the R2 bucket. This is an **R2-specific token**, not a standard Cloudflare API token — it is created inside the R2 section of the dashboard, not the API Tokens page.

**Type:** R2 API Token — create at [Cloudflare Dashboard](https://dash.cloudflare.com/) → R2 → Manage R2 API Tokens → Create API Token.

**Permissions:**

| Permission | Scope |
|------------|-------|
| Object Read & Write | Apply to specific bucket (your Velero bucket) |

**Where it goes:** `helmfile/environments/<env>/secrets/velero.enc.yaml` → `velero.accessKeyId` and `velero.secretAccessKey`

Set it during `mise run secrets:init <env>` when prompted for the velero secret. The Access Key ID and Secret Access Key are shown only once at token creation time — copy them immediately.

---

#### Summary

| Token | Type | Key permissions | Stored in |
|-------|------|-----------------|-----------|
| DNS | Cloudflare API Token | Zone:DNS:Edit, Zone:Zone:Read | `cert-manager-config.enc.yaml` |
| Terraform | Cloudflare API Token | Account:R2 Storage:Edit | Environment variable only |
| R2 (Velero) | R2 API Token | Object Read & Write | `velero.enc.yaml` |

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
