# Forking the Homelab

This homelab is designed as a template. Fork it to your own repository to store your configs, secrets, and environment-specific settings. The upstream repository contains only the shared infrastructure code — your fork holds everything that makes the deployment yours.

## What lives in your fork

| Area | Files | Description |
|------|-------|-------------|
| Environment config | `helmfile/environments/<env>/config.yaml` | Domain names, IP pools, storage sizes, replica counts |
| Encrypted secrets | `helmfile/environments/<env>/secrets/*.enc.yaml` | API keys, passwords, webhook URLs (SOPS-encrypted) |
| SOPS configuration | `.sops.yaml` | Your PGP key fingerprint for encryption |
| KubeContext names | `helmfile/environments.yaml.gotmpl` | Your cluster context names |
| Inventory | `metal/k3s/inventory.yml` | Your bare-metal node IPs and SSH config |

Everything else (Helm charts, common values, scripts, playbooks) is shared and should sync from upstream.

## Setup

### 1. Fork and clone

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/<you>/homelab.git
cd homelab
```

### 2. Add upstream remote

```bash
git remote add upstream https://github.com/<original>/homelab.git
```

This lets you pull infrastructure updates without overwriting your configs:

```bash
git fetch upstream
git merge upstream/main --no-commit   # review changes before committing
```

### 3. Configure SOPS

Replace the PGP fingerprint in `.sops.yaml` with your own key:

```yaml
creation_rules:
  - path_regex: \.(yaml|yml|json)$
    key_groups:
    - pgp:
      - <YOUR_PGP_FINGERPRINT>
```

Or switch to [age](https://github.com/FiloSottile/age) if you prefer:

```yaml
creation_rules:
  - path_regex: \.(yaml|yml|json)$
    age:
      - <YOUR_AGE_PUBLIC_KEY>
```

### 4. Configure your environments

```bash
# Create environment directories
mkdir -p helmfile/environments/{dev,prod}/secrets

# Copy and edit the config template for each environment
cp helmfile/config.template.yaml helmfile/environments/dev/config.yaml
cp helmfile/config.template.yaml helmfile/environments/prod/config.yaml
```

Edit each `config.yaml` with your values:

```yaml
general:
  root_dns: example.com           # your domain
  dns:
    provider: cloudflare
metallb:
  ipPool: 192.168.1.100-192.168.1.110  # your network
grafana:
  storage: 10Gi
  port: 30080
prometheus:
  replicas: 1
  retention: 15d
  storage: 10Gi
alertmanager:
  replicas: 1
  storage: 1Gi
```

See [CONFIG.md](./CONFIG.md) for all available options.

### 5. Initialize secrets

Delete the upstream's encrypted secret files (they were encrypted with a different key):

```bash
rm -f helmfile/environments/*/secrets/*.enc.yaml
```

Run the interactive secret initializer:

```bash
./scripts/init-secrets.sh dev
./scripts/init-secrets.sh prod
```

This prompts for each secret value and encrypts them with your SOPS key.

See [SECRETS.md](./SECRETS.md) for the full list of required secrets.

### 6. Update kubecontext names

Edit `helmfile/environments.yaml.gotmpl` to match your Kubernetes context names:

```yaml
environments:
  dev:
    kubeContext: your-dev-context
  prod:
    kubeContext: your-prod-context
```

Verify your available contexts with `kubectl config get-contexts`.

### 7. Provision and deploy

```bash
# Provision K3s (update metal/k3s/inventory.yml first)
cd metal/k3s && ./run.sh

# Deploy
./scripts/install-helmfiles.sh dev
```

## Syncing with upstream

Pull infrastructure updates while preserving your configs:

```bash
git fetch upstream
git merge upstream/main --no-commit
```

Files that will never conflict:
- `helmfile/environments/*/config.yaml` — not in upstream
- `helmfile/environments/*/secrets/*.enc.yaml` — encrypted with your key
- `.sops.yaml` — your key fingerprint
- `metal/k3s/inventory.yml` — gitignored

Files that may conflict after upstream changes:
- `helmfile/common/values/*.yaml.gotmpl` — shared chart values (review carefully)
- `helmfile/common/common.yaml.gotmpl` — release definitions
- Scripts in `scripts/`

## What not to commit to your fork

The `.gitignore` already excludes plaintext secrets (`*.secrets.yaml`). Never commit:
- `*.secrets.yaml` files (plaintext working copies)
- `.env` files
- SSH keys or PGP private keys
- `.vault_pass` / `.vault_password` files
