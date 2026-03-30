# Scripts Documentation

This document describes all automation scripts in the homelab repository, their purpose, usage, and how they relate to each other.

## Overview

The repository contains 7 shell scripts organized into three functional groups:

- **Validation scripts** - Verify prerequisites and cluster health
- **Helmfile lifecycle scripts** - Deploy and destroy Helmfile-managed services
- **Secrets management scripts** - Encrypt and decrypt environment secrets
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
        │                                  │  │  .enc.yaml ->         │ │
        │                                  │  │  .secrets.yaml        │ │
        │                                  │  └──────────┬────────────┘ │
        │                                  │             │              │
        │                                  │  Steps:     │              │
        │                                  │  [1/4] Apply CRDs (001)   │
        │                                  │  [2/4] Apply certs (002)  │
        │                                  │  [3/4] Apply common       │
        │                                  │  [4/4] Apply ingresses(003)│
        │                                  └──────────────────────────────┘
        │                                            │
        │                                            ▼
        │                                     Helmfile Releases
        │                                     (001-crds, 002-certs,
        │                                      003-ingresses, common)
        │
        │
        │  scripts/destroy-helmfiles.sh
        │  ┌──────────────────────────────┐
        │  │  Helmfile Destroy Orchestrator│
        │  │                              │
        │  │  [1/6] Longhorn deletion flag│
        │  │  [2/6] Destroy ingresses (003)│
        │  │  [3/6] Destroy common        │
        │  │  [4/6] Destroy certs (002)   │
        │  │  [5/6] Destroy CRDs (001)    │
        │  │  [6/6] Clean stuck resources │
        │  └──────────────────────────────┘
        │
        │
        │  scripts/sops-encrypt-secrets.sh
        │  ┌──────────────────────────────┐
        │  │  Secrets Encryption           │
        │  │  .secrets.yaml -> .enc.yaml  │
        └──┤  (standalone, not called by  │
           │   other scripts)             │
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

**Execution flow (4 steps):**
1. Apply CRDs via `helmfile/001-crds.helmfile.yaml`
2. Apply certifications via `helmfile/002-certs.helmfile.yaml.gotmpl`
3. Apply common releases via `helmfile.yaml.gotmpl`
4. Apply ingresses via `helmfile/003-ingresses.helmfile.yaml.gotmpl`

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

**Execution flow (6 steps):**
1. Set Longhorn `deleting-confirmation-flag` to allow cleanup
2. Destroy ingresses (`003-ingresses.helmfile.yaml.gotmpl`)
3. Destroy common releases (`helmfile.yaml.gotmpl`)
4. Destroy certifications (`002-certs.helmfile.yaml.gotmpl`)
5. Destroy CRDs (`001-crds.helmfile.yaml`)
6. Clean stuck resources (Longhorn volumes/PVCs, namespace finalizers, Longhorn CRDs)

**Interactive:** Prompts for confirmation before proceeding (irreversible).

---

### `scripts/sops-decrypt-secrets.sh`

**Purpose:** Decrypts all `.enc.yaml` files in an environment's secrets directory, producing `.secrets.yaml` files.

**Usage:**
```bash
./scripts/sops-decrypt-secrets.sh <environment>
# Example:
./scripts/sops-decrypt-secrets.sh dev
./scripts/sops-decrypt-secrets.sh prod
```

**Source directory:** `helmfile/environments/<env>/secrets/*.enc.yaml`
**Output:** `helmfile/environments/<env>/secrets/*.secrets.yaml`

**Standalone:** Not called by other scripts. Run manually before deploying if encrypted secrets need to be decrypted.

---

### `scripts/sops-encrypt-secrets.sh`

**Purpose:** Encrypts all `.secrets.yaml` files in an environment's secrets directory, producing `.enc.yaml` files for version control.

**Usage:**
```bash
./scripts/sops-encrypt-secrets.sh <environment>
# Example:
./scripts/sops-encrypt-secrets.sh dev
./scripts/sops-encrypt-secrets.sh prod
```

**Source directory:** `helmfile/environments/<env>/secrets/*.secrets.yaml`
**Output:** `helmfile/environments/<env>/secrets/*.enc.yaml`

**Standalone:** Not called by other scripts. Run manually after editing secrets.

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
  ├── helmfile: 001-crds
  ├── helmfile: 002-certs
  ├── helmfile: common
  └── helmfile: 003-ingresses
```

### Destroy Environment

```
destroy-helmfiles.sh <env>
  ├── Longhorn cleanup
  ├── helmfile: 003-ingresses (destroy)
  ├── helmfile: common (destroy)
  ├── helmfile: 002-certs (destroy)
  ├── helmfile: 001-crds (destroy)
  └── Stuck resource cleanup
```

### Edit Secrets

```
sops-decrypt-secrets.sh <env>   ──>  Edit .secrets.yaml  ──>  sops-encrypt-secrets.sh <env>
```
