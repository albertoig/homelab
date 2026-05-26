# Scripts Documentation

This document describes all automation scripts in the homelab repository, their purpose, usage, and how they relate to each other.

## Makefile shortcuts

The `Makefile` at the repo root wraps the most common script operations. Run `make help` to see all available targets.

| Make target | Underlying script | Notes |
|-------------|-------------------|-------|
| `make check` | `scripts/check-requirements.sh` | |
| `make check-k8s` | `scripts/check-kubernetes.sh` | |
| `make provision [PLAYBOOK=site]` | `metal/k3s/run.sh` | |
| `make install [ENV=dev]` | `scripts/install-helmfiles.sh` | |
| `make destroy [ENV=dev]` | `scripts/destroy-helmfiles.sh` | |
| `make secrets-init [ENV=dev]` | `scripts/init-secrets.sh` | |
| `make secrets-encrypt [ENV=dev] [CHART=]` | `scripts/sops-encrypt-secrets.sh` | |
| `make secrets-decrypt [ENV=dev] [CHART=]` | `scripts/sops-decrypt-secrets.sh` | |
| `make secrets-check` | `scripts/check-secrets.sh` | |
| `make lint` | `pre-commit run --all-files` | |
| `make helm-lint` | `helm lint` loop over `charts/*/` | |
| `make helmfile-lint [ENV=dev]` | `helmfile lint --skip-deps` | |
| `make pre-commit-install` | `pre-commit install` (both hooks) | Run once after cloning |

## Overview

The repository contains 8 shell scripts organized into three functional groups:

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
│  - ansible ping         │               │  │  │ kubectl, terraform │ │ │
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

### `scripts/check-requirements.sh`

**Purpose:** Validates that all required CLI tools and Helm plugins are installed before running Helmfile operations.

**Usage:**
```bash
./scripts/check-requirements.sh
```

**Checks:**
- CLI tools: `kubectl`, `terraform`, `helm`, `helmfile`, `sops`, `ansible`
- Helm plugins: `secrets`, `secrets-getter`, `secrets-post-renderer`, `diff`

**Exit codes:**
- `0` - All requirements met
- `1` - One or more requirements missing

**Called by:** `install-helmfiles.sh`

---

### `scripts/check-kubernetes.sh`

**Purpose:** Verifies that `kubectl` can access the cluster and the server version is >= 1.33.

**Usage:**
```bash
./scripts/check-kubernetes.sh
```

**Checks:**
- `kubectl` binary exists
- Cluster is reachable (`kubectl cluster-info`)
- Server version >= 1.33

**Exit codes:**
- `0` - Kubernetes check passed
- `1` - Cluster unreachable or version too low

**Called by:** `install-helmfiles.sh`

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
install-helmfiles.sh <env>
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
