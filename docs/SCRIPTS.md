# Scripts Documentation

This document describes all automation scripts in the homelab repository, their purpose, usage, and how they relate to each other.

## mise task shortcuts

All common operations are defined as mise tasks in `.mise.toml`. Run `mise tasks` to see all available tasks.

| mise task | Underlying script | Notes |
|-----------|-------------------|-------|
| `mise run setup` | mise install + helm plugins + pre-commit + terraform init | Run once after cloning |
| `mise run check` | `scripts/infra/preflight.sh` | |
| `mise run doctor` | `scripts/infra/doctor.sh` | `-- --fix` to remediate |
| `mise run provision [playbook]` | `metal/k3s/run.sh` | Default playbook: `site` |
| `mise run install <env>` | terraform apply → `scripts/velero-secrets.sh` → `scripts/install-helmfiles.sh` | |
| `mise run destroy <env>` | `scripts/destroy-helmfiles.sh` → terraform destroy | |
| `mise run secrets:init <env>` | `scripts/init-secrets.sh` | |
| `mise run secrets:encrypt <env> [chart]` | `scripts/sops-encrypt-secrets.sh` | |
| `mise run secrets:decrypt <env> [chart]` | `scripts/sops-decrypt-secrets.sh` | |
| `mise run secrets:check` | `scripts/secrets/validate.sh` | Checks all envs if no env given |
| `mise run lint` | `pre-commit run --all-files` | |
| `mise run tf:init` | `terraform init` | |
| `mise run tf:plan <env>` | `scripts/terraform.sh plan` | |
| `mise run tf:apply <env>` | `scripts/terraform.sh apply` | |
| `mise run tf:destroy <env>` | `scripts/terraform.sh destroy` | |

## Overview

The repository contains 10 shell scripts (plus a `scripts/lib/` directory for shared utilities) organized into four functional groups:

- **Validation scripts** - Verify prerequisites and cluster health
- **Helmfile lifecycle scripts** - Deploy and destroy Helmfile-managed services
- **Secrets management scripts** - Initialize, encrypt, and decrypt per-chart environment secrets
- **Infrastructure provisioning** - Bootstrap K3s on bare metal via Ansible

## Hierarchy Diagram

```
metal/k3s/run.sh                          scripts/install-helmfiles.sh
┌─────────────────────────┐               ┌──────────────────────────────┐
│  Ansible K3s Bootstrap  │               │  Helmfile Install Orchestrator│
│                         │               │                              │
│  - SSH key setup        │               │  ┌─────────────────────────┐ │
│  - Decrypt inventory    │               │  │ scripts/                │ │
│    (sops)               │               │  │  check-requirements.sh  │ │
│  - ansible-galaxy       │               │  │  ┌───────────────────┐ │ │
│  - ansible ping         │               │  │  │ kubectl            │ │ │
│  - sysctl tuning        │               │  │  │ helm, helmfile     │ │ │
│  - k3s orchestration    │               │  │  │ sops, ansible      │ │ │
│    playbook             │               │  │  │ helm plugins       │ │ │
└────────────┬────────────┘               │  │  └───────────────────┘ │ │
             │                            │  └──────────┬────────────┘ │
             │                            │             │              │
             ▼                            │  ┌──────────▼────────────┐ │
    K3s Cluster                            │  │ scripts/              │ │
        │                                  │  │  check-kubernetes.sh  │ │
        │                                  │  │  ┌─────────────────┐  │ │
        │                                  │  │  │ cluster access  │  │ │
        │                                  │  │  │ version >= 1.33 │  │ │
        │                                  │  │  └─────────────────┘  │ │
        │                                  │  └──────────┬────────────┘ │
        │                                  │             │              │
        │                                  │  ┌──────────▼────────────┐ │
        │                                  │  │ scripts/              │ │
        │                                  │  │  sops-decrypt-secrets │ │
        │                                  │  │  *.enc.yaml ->        │ │
        │                                  │  │  *.secrets.yaml       │ │
        │                                  │  └──────────┬────────────┘ │
        │                                  │             │              │
        │                                  │  Steps:     │              │
        │                                  │  [1/1] Sync all releases   │
        │                                  └──────────────────────────────┘
        │                                            │
        │                                            ▼
        │                                     Helmfile Releases
        │                                     (all via principal helmfile)
        │
        │
          │  scripts/destroy-helmfiles.sh
          │  ┌──────────────────────────────┐
          │  │  Helmfile Destroy Orchestrator│
          │  │                              │
          │  │  [1/4] Longhorn deletion flag│
          │  │  [2/4] Destroy all helmfiles │
          │  │  [3/4] Clean stuck resources │
          │  │  [4/4] Final message         │
          │  └──────────────────────────────┘
         │


         scripts/sops-encrypt-secrets.sh
         ┌──────────────────────────────┐
         │  Secrets Encryption           │
         │  *.secrets.yaml -> *.enc.yaml │
         │  (standalone, not called by   │
         │   other scripts)             │
         └──────────────────────────────┘


        scripts/init-secrets.sh
        ┌──────────────────────────────┐
        │  Interactive Secret Init      │
        │  Templates -> .secrets.yaml   │
        │  -> .enc.yaml (auto-encrypt)  │
        └──────────────────────────────┘
```

## Scripts

### `scripts/infra/preflight.sh`

**Purpose:** Unified preflight check before deploying. Validates CLI tools, Helm plugins, cluster connectivity, and the presence of encrypted secret files, rendered as side-by-side Tools and Secrets boxes.

**Usage:**
```bash
./scripts/infra/preflight.sh [environment]   # prompts to choose dev/prod if omitted
```

The environment is resolved through `scripts/lib/env.sh` (argument → `ENV` variable → interactive prompt), matching the other scripts.

**Checks:**
- CLI tools: `mise`, `kubectl`, `helm`, `helmfile`, `sops`, `ansible`, `poetry`, `gum`, `fzf`, `jq`, `yq`
- Helm plugins: `secrets`, `secrets-getter`, `secrets-post-renderer`, `diff`
- Cluster is reachable (`kubectl cluster-info`), labelled with the active kube context
- Each secret template has a matching `.enc.yaml` for the selected environment (existence only — see `scripts/secrets/validate.sh` for content validation)

**Exit codes:**
- `0` - All checks passed
- `1` - One or more checks failed

**Called by:** `scripts/helm/install.sh`

---

### `scripts/infra/doctor.sh`

**Purpose:** Diagnoses common cluster failure patterns against the selected environment's kube context (`homelab-<env>`). Read-only by default; `--fix` applies remediations, each behind a confirmation prompt (`--yes` skips prompts).

**Usage:**
```bash
mise run doctor                    # prompts for environment, diagnose only
mise run doctor prod               # diagnose prod
mise run doctor -- prod --fix      # diagnose prod and offer fixes
mise run doctor -- prod --fix --yes
```

**Checks:**
- Services stuck Terminating with finalizers (fix: strip finalizers)
- Pods stuck Pending past threshold, with their recent events (fix: force delete)
- VolumeAttachments stuck detaching (fix: delete)
- Failed/Evicted pods (fix: delete)
- Helm releases in pending/failed state (report only)
- Nodes NotReady or under resource pressure (report only)
- PVCs stuck Pending (report only)
- OpenBao sealed (report only, prints the unseal command)

**Exit codes:**
- `0` - No issues found
- `1` - One or more issues found (even if fixed in the same run)

**Notes:** Replaces the `prepare` hooks that previously ran these remediations blindly on every deploy from `helmfile/releases/004-core-apps.helmfile.yaml.gotmpl`. Threshold for "stuck" is 180s, override with `DOCTOR_STUCK_SECONDS`.

---

### `scripts/install-helmfiles.sh`

**Purpose:** Main deployment orchestrator. Installs Helmfile-managed releases for a given environment in the correct order.

**Usage:**
```bash
./scripts/install-helmfiles.sh <environment>
# Example:
./scripts/install-helmfiles.sh dev
./scripts/install-helmfiles.sh prod
```

**Execution flow (1 step):**
1. Sync all releases using principal `helmfile.yaml.gotmpl` (includes CRDs, certs, common, ingresses)

**Prerequisites (run automatically):**
- `check-requirements.sh`
- `check-kubernetes.sh`

**Environment validation:** Requires `dev` or `prod` and checks that `helmfile/environments/<env>/` exists.

**Interactive:** Prompts for confirmation before proceeding.

---

### `scripts/destroy-helmfiles.sh`

**Purpose:** Tears down all Helmfile-managed releases for a given environment. Destroys resources in reverse dependency order and cleans up stuck Kubernetes resources.

**Usage:**
```bash
./scripts/destroy-helmfiles.sh <environment>
# Example:
./scripts/destroy-helmfiles.sh dev
./scripts/destroy-helmfiles.sh prod
```

**Execution flow (4 steps):**
1. Set Longhorn `deleting-confirmation-flag` to allow cleanup
2. Destroy all helmfiles using principal `helmfile.yaml.gotmpl` (includes CRDs, certs, common, ingresses)
3. Clean stuck resources (Longhorn volumes/PVCs, namespace finalizers, Longhorn CRDs)
4. Display completion message

**⚠️ Warning:** This will delete ALL PersistentVolumes and permanent storage data. Data loss is irreversible.

**Interactive:** Prompts for confirmation before proceeding (irreversible).

---

### `scripts/sops-decrypt-secrets.sh`

**Purpose:** Decrypts per-chart `.enc.yaml` files in an environment's secrets directory, producing `.secrets.yaml` files.

**Usage:**
```bash
# Decrypt all charts
./scripts/sops-decrypt-secrets.sh <environment>

# Decrypt a single chart
./scripts/sops-decrypt-secrets.sh <environment> <chart-name>

# Examples:
./scripts/sops-decrypt-secrets.sh prod
./scripts/sops-decrypt-secrets.sh prod grafana
```

**Source directory:** `helmfile/environments/<env>/secrets/*.enc.yaml`
**Output:** `helmfile/environments/<env>/secrets/*.secrets.yaml`

**Standalone:** Not called by other scripts. Run manually before deploying if encrypted secrets need to be reviewed.

---

### `scripts/sops-encrypt-secrets.sh`

**Purpose:** Encrypts per-chart `.secrets.yaml` files in an environment's secrets directory, producing `.enc.yaml` files for version control.

**Usage:**
```bash
# Encrypt all charts
./scripts/sops-encrypt-secrets.sh <environment>

# Encrypt a single chart
./scripts/sops-encrypt-secrets.sh <environment> <chart-name>

# Examples:
./scripts/sops-encrypt-secrets.sh prod
./scripts/sops-encrypt-secrets.sh prod grafana
```

**Source directory:** `helmfile/environments/<env>/secrets/*.secrets.yaml`
**Output:** `helmfile/environments/<env>/secrets/*.enc.yaml`

**Called by:** `init-secrets.sh` (after generating per-chart files). Can also be run standalone after manually editing secrets.

---

### `scripts/init-secrets.sh`

**Purpose:** Interactively initializes secrets for an environment from per-chart template files. Reads templates from `helmfile/secret-templates/`, prompts for each value with descriptions, generates per-chart `.secrets.yaml` files, and encrypts them with sops.

**Usage:**
```bash
./scripts/init-secrets.sh <environment>
# Example:
./scripts/init-secrets.sh dev
./scripts/init-secrets.sh prod
```

**Execution flow (5 phases):**
1. Validate environment and check for existing secrets (warns before overwriting)
2. Extract key paths, descriptions, and line types from all template files
3. Prompt interactively for each secret value (pre-fills from existing `.secrets.yaml` or decrypted `.enc.yaml`)
4. Generate per-chart `<chart>.secrets.yaml` files in `helmfile/environments/<env>/secrets/`
5. Encrypt each chart to `<chart>.enc.yaml` via sops

**Templates:** Secret templates with comment-based descriptions are in `helmfile/secret-templates/*.template.yaml`. Each template corresponds to one chart and uses `# --- name ---` as a section header.

**Pre-filling:** If a chart already has a `.secrets.yaml` or `.enc.yaml` file, existing values are shown as defaults in square brackets. Press Enter to keep the existing value.

**Output structure:**
```
helmfile/environments/<env>/secrets/
  grafana.secrets.yaml          # plaintext (gitignored)
  grafana.enc.yaml              # encrypted (committed)
  prometheus-stack.secrets.yaml
  prometheus-stack.enc.yaml
  authentik.secrets.yaml
  authentik.enc.yaml
  cert-manager-config.secrets.yaml
  cert-manager-config.enc.yaml
```

**Standalone:** Not called by other scripts. Run once to initialize or update secrets for an environment.

---

### `scripts/velero-secrets.sh`

**Purpose:** Reads Terraform outputs for the given environment, then writes and SOPS-encrypts `helmfile/environments/<env>/secrets/velero.enc.yaml` with all four Velero values: `bucket`, `s3Url` (from Terraform), `accessKeyId`, and `secretAccessKey` (from `CLOUDFLARE_R2_ACCESS_KEY_ID` / `CLOUDFLARE_R2_SECRET_ACCESS_KEY` in the environment).

**Usage:**
```bash
./scripts/velero-secrets.sh <environment>
# Example:
./scripts/velero-secrets.sh dev
./scripts/velero-secrets.sh prod
```

**Prerequisites:** R2 credentials must be set in `.mise.local.toml` and Terraform must already be applied for the environment.

**Called by:** `scripts/install.sh` (automatically, between `terraform apply` and `install-helmfiles.sh`).

---

### `scripts/secrets/validate.sh`

**Purpose:** Validates that all per-chart secret files are present and contain the same fields as their corresponding templates. Decrypts `.enc.yaml` files on the fly to compare against `helmfile/secret-templates/*.template.yaml`.

**Usage:**
```bash
# Check all environments
./scripts/secrets/validate.sh

# Check a single environment
./scripts/secrets/validate.sh <environment>
# Example:
./scripts/secrets/validate.sh dev
./scripts/secrets/validate.sh prod
```

**Checks:**
- Each template in `helmfile/secret-templates/` has a matching `.enc.yaml` or `.secrets.yaml` in the target environment
- All keys in the template are present in the secret file (missing keys reported as errors)
- Extra keys in the secret file not present in the template (reported as warnings)

**Exit codes:**
- `0` - All secrets present and up to date (warnings are non-fatal)
- `1` - One or more secret files missing or have missing fields

**Called by:** `mise run secrets:check`

---

### `scripts/install-helm-plugins.sh`

**Purpose:** Installs all required Helm plugins idempotently. Skips plugins that are already installed. Sets up the GPG keyring for the `helm-secrets` plugin family if not already present.

**Usage:**
```bash
./scripts/install-helm-plugins.sh
```

**Installs:**
- `secrets` — helm-secrets v4.7.4
- `secrets-getter` — helm-secrets-getter v4.7.4
- `secrets-post-renderer` — helm-secrets-post-renderer v4.7.4
- `diff` — helm-diff (no GPG verification)

**Called by:** `mise run setup` (as part of the full setup task)

---

### `metal/k3s/run.sh`

**Purpose:** Provisions a K3s cluster on bare metal nodes using Ansible. Handles SSH setup, inventory decryption, and playbook execution.

**Usage:**
```bash
cd metal/k3s
./run.sh [playbook]
# Default playbook: site
# Example:
./run.sh
./run.sh site
```

**Execution flow:**
1. Validate SSH key exists at `~/.ssh/homelab`
2. Load SSH key into agent
3. Decrypt `inventory.sops.yml` (via sops) to temporary `inventory.yml`
4. Install Ansible collections from `requirements.yml`
5. Validate inventory
6. Ping all nodes
7. Apply sysctl tuning (`playbooks/sysctl-tuning.yml`)
8. Run the specified K3s orchestration playbook

**Security:** Decrypted inventory is cleaned up on exit via `trap`.

**Standalone:** Not called by other scripts. Run first to bootstrap the cluster.

---

## Workflow Summary

### Initial Cluster Setup

```
metal/k3s/run.sh  ──>  K3s Cluster
```

### Deploy Services

```
mise run install <env>
  ├── terraform apply          (provisions R2 bucket)
  ├── velero-secrets.sh        (reads outputs, writes velero.enc.yaml)
  └── install-helmfiles.sh
        ├── check-requirements.sh
        ├── check-kubernetes.sh
        └── helmfile sync (all releases via principal helmfile)
```

### Destroy Environment

```
destroy-helmfiles.sh <env>
  ├── ⚠️ Warning: deletes all PVs and storage
  ├── Longhorn deletion flag
  ├── helmfile destroy (all releases via principal helmfile)
  └── Stuck resource cleanup
```

### Edit Secrets

```
init-secrets.sh <env>          (interactive prompts, auto-encrypts)
  └── sops-encrypt-secrets.sh  (called automatically per chart)

Manual edit workflow:
sops-decrypt-secrets.sh <env> [chart]  ──>  Edit .secrets.yaml  ──>  sops-encrypt-secrets.sh <env> [chart]
```
