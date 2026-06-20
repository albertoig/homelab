# Scripts Documentation

This document describes the automation scripts in the homelab repository, their
purpose, usage, and how they relate to each other.

Scripts are organised into domain-based subdirectories under `scripts/`, and
most are driven through `mise` tasks rather than called directly. Run
`mise tasks` to see everything available.

## mise task shortcuts

| mise task | Underlying script | Notes |
|-----------|-------------------|-------|
| `mise run setup` | mise install + poetry + npm + `scripts/helm/install-plugins.sh` + pre-commit + terraform init | Run once after cloning |
| `mise run check` | `scripts/infra/preflight.sh` | Tools, plugins, cluster, secrets |
| `mise run doctor` | `scripts/infra/doctor.sh` | `-- <env> --fix` to remediate, `--yes` non-interactive |
| `mise run provision [playbook]` | `metal/k3s/run.sh` | Default playbook: `site` |
| `mise run install` | `scripts/helm/install.sh` | Prompts for env; terraform → velero secrets → helmfile sync |
| `mise run destroy <env>` | `scripts/helm/destroy.sh` | ⚠️ irreversible |
| `mise run helmfile:update-locks` | `scripts/helm/update-locks.sh` | Refresh lock files for all envs |
| `mise run openbao:preflight [env]` | `scripts/apps/setup-openbao-preflight.sh` | Pre-checks for OpenBao setup |
| `mise run openbao:setup [env]` | `scripts/apps/setup-openbao.sh` | Init + unseal + wire ESO (idempotent) |
| `mise run secrets:init [env]` | `scripts/secrets/init.sh` | Interactive secret init from templates |
| `mise run secrets:encrypt <env> [chart]` | `scripts/secrets/encrypt.sh` | |
| `mise run secrets:decrypt <env> [chart]` | `scripts/secrets/decrypt.sh` | |
| `mise run secrets:check` | `scripts/secrets/validate.sh` | All envs if none given |
| `mise run lint` | `lint:ansible` + `lint:helm` + `lint:helmfile` | |
| `mise run lint:commits` | commitlint | |
| `mise run test` / `test:smoke` / `test:k8s` | `poetry run pytest [path]` | Python integration tests |
| `mise run test:shell` | `shellspec tests/shell` | Shell BDD tests |
| `mise run tf:init` | `terraform init` | |
| `mise run tf:plan\|apply\|destroy <env>` | `scripts/infra/terraform.sh` | |
| `mise run clean` | removes `node_modules`, `.venv`, `.terraform`, caches | |

## Overview

`scripts/` is grouped by domain:

```
scripts/
├── lib/        Shared, sourced-only helpers (no side effects on their own)
├── infra/      Preflight, cluster doctor, terraform wrapper
├── helm/       Helmfile install/destroy, plugin install, lock updates
├── secrets/    SOPS bootstrap secrets: init/encrypt/decrypt/validate + velero
└── apps/       Per-application post-deploy setup (OpenBao)
```

Two complementary secret systems live here, and the boundary matters:

- **SOPS** (`scripts/secrets/`) — bootstrap-time secrets the helmfile needs at
  render time (SSO client secrets, Cloudflare tokens, etc.), committed encrypted
  under `helmfile/environments/<env>/secrets/`.
- **OpenBao + External Secrets Operator** (`scripts/apps/`) — runtime secret
  manager wired up after deploy, for secrets consumed by workloads at runtime.

## `scripts/lib/` — shared helpers

Sourced by the other scripts; none are meant to be executed directly.

| File | Provides |
|------|----------|
| `colors.sh` | gum colour palette + `info`/`warn`/`error`/`success` log helpers |
| `header.sh` | `show_header` ASCII banner |
| `env.sh` | Environment selector → `ENV` (argument → `$ENV` → interactive `gum choose`), validated against `dev`/`prod` |
| `openbao.sh` | Shared OpenBao / ESO identifiers (namespace, pod, KV path, policy, store name, CRD) |
| `secrets.sh` | YAML helpers used by the secrets scripts |
| `terraform-env.sh` | Maps `ENV` to Terraform workspace / variables |

---

## `scripts/infra/`

### `preflight.sh`

**Purpose:** Unified preflight check before deploying. Validates CLI tools, Helm
plugins, cluster connectivity, and the presence of encrypted secret files,
rendered as side-by-side Tools and Secrets boxes.

**Usage:** `./scripts/infra/preflight.sh [environment]` (or `mise run check`) —
prompts to choose dev/prod if omitted, via `lib/env.sh`.

**Checks:** CLI tools (`mise`, `kubectl`, `helm`, `helmfile`, `sops`, `ansible`,
`poetry`, `gum`, `fzf`, `jq`, `yq`), Helm plugins (`secrets`, `secrets-getter`,
`secrets-post-renderer`, `diff`), cluster reachability, and that each secret
template has a matching `.enc.yaml` for the selected environment.

**Called by:** `scripts/helm/install.sh`.

### `doctor.sh`

**Purpose:** Diagnoses common cluster failure patterns against the selected
environment's kube context (`homelab-<env>`). Read-only by default; `--fix`
applies remediations behind confirmation prompts (`--yes` skips them).

**Usage:**
```bash
mise run doctor                  # prompt for env, diagnose only
mise run doctor -- prod --fix    # diagnose prod and offer fixes
mise run doctor -- prod --fix --yes
```

**Checks:** stuck-Terminating services (fix: strip finalizers), pods stuck
Pending (fix: force delete), VolumeAttachments stuck detaching (fix: delete),
failed/evicted pods (fix: delete), helm releases pending/failed, nodes
NotReady/under pressure, PVCs Pending, OpenBao sealed (report only). Threshold
for "stuck" is 180s, override with `DOCTOR_STUCK_SECONDS`.

### `terraform.sh`

**Purpose:** Thin wrapper around `terraform` that selects the workspace and
variables for the chosen environment via `lib/terraform-env.sh`.

**Usage:** `./scripts/infra/terraform.sh <plan|apply|destroy> <environment>`
(or `mise run tf:plan|tf:apply|tf:destroy <env>`).

---

## `scripts/helm/`

### `install.sh`

**Purpose:** Main deployment orchestrator. Resolves the environment via
`lib/env.sh`, runs preflight, applies Terraform (R2 bucket), refreshes the
Velero secret from Terraform outputs, then syncs all helmfile releases via the
principal `helmfile.yaml.gotmpl`.

**Usage:** `mise run install` (prompts for env). Interactive — confirms before
applying.

### `destroy.sh`

**Purpose:** Tears down all helmfile releases for an environment in reverse
dependency order and cleans up stuck Kubernetes resources (Longhorn
volumes/PVCs, namespace finalizers).

**Usage:** `mise run destroy <environment>`.

**⚠️ Warning:** Deletes all PersistentVolumes and permanent storage. Irreversible
— prompts for confirmation.

### `install-plugins.sh`

**Purpose:** Installs the required Helm plugins idempotently and sets up the GPG
keyring for the `helm-secrets` family.

**Installs:** `secrets`, `secrets-getter`, `secrets-post-renderer` (helm-secrets
v4.7.4) and `diff` (helm-diff).

**Called by:** `mise run setup`.

### `update-locks.sh`

**Purpose:** Regenerates the helmfile lock files (`helmfile/locks/<env>/*.lock`)
for every environment so pinned chart versions stay reproducible.

**Usage:** `mise run helmfile:update-locks`.

---

## `scripts/secrets/` — SOPS bootstrap secrets

```
helmfile/secret-templates/<chart>.template.yaml   (templates with descriptions)
        │  init.sh        (interactive prompts; @autogen fields generated)
        ▼
helmfile/environments/<env>/secrets/<chart>.secrets.yaml   (plaintext, gitignored)
        │  encrypt.sh     (or auto-encrypted by init.sh)
        ▼
helmfile/environments/<env>/secrets/<chart>.enc.yaml       (encrypted, committed)
```

See [SECRETS.md](SECRETS.md) for the per-chart key reference.

### `init.sh`

**Purpose:** Interactively initialises secrets for an environment from the
per-chart templates in `helmfile/secret-templates/`. Prompts for each value
(pre-filling from existing `.secrets.yaml` / decrypted `.enc.yaml`), generates
per-chart `.secrets.yaml` files, and encrypts them with SOPS. Fields marked
`@autogen` in a template are generated automatically.

**Usage:** `mise run secrets:init [environment]`.

### `encrypt.sh` / `decrypt.sh`

**Purpose:** Encrypt `.secrets.yaml` → `.enc.yaml` (committed) and decrypt back
for editing. Operate on all charts in an environment or a single named chart.

**Usage:** `mise run secrets:encrypt <env> [chart]` /
`mise run secrets:decrypt <env> [chart]`.

### `validate.sh`

**Purpose:** Validates that every per-chart secret file is present and contains
the same fields as its template, decrypting `.enc.yaml` on the fly to compare.
Missing keys are errors; extra keys are warnings.

**Usage:** `mise run secrets:check` (all environments if none given).

### `velero.sh`

**Purpose:** Reads Terraform outputs for the environment and writes/encrypts
`velero.enc.yaml` with `bucket`, `s3Url` (from Terraform), `accessKeyId`, and
`secretAccessKey` (from `CLOUDFLARE_R2_*` in the environment).

**Called by:** `scripts/helm/install.sh`, between `terraform apply` and the
helmfile sync. Requires R2 credentials in `.mise.local.toml`.

---

## `scripts/apps/` — OpenBao runtime secrets

### `setup-openbao-preflight.sh`

**Purpose:** Verifies everything `setup-openbao.sh` needs before it runs — the
CLI tools (`gum`, `kubectl`, `jq`) and cluster resources (OpenBao namespace and
pod, External Secrets namespace, `ClusterSecretStore` CRD) — failing fast with a
clear report. Resolves the environment via `lib/env.sh` and targets
`homelab-<env>`.

**Usage:** `mise run openbao:preflight [environment]`. Also run as an inline gate
at the start of `setup-openbao.sh` (quiet mode).

### `setup-openbao.sh`

**Purpose:** Configures OpenBao after the helmfile deploy. **Idempotent and
resumable** — every step is create-or-update, so a re-run repairs whatever a
previous run left unfinished without ever re-initialising OpenBao or
regenerating the unseal keys / root token.

**Steps:** wait for the pod to start → initialise (only when never initialised;
prints the unseal keys + root token to save) → unseal → enable KV v2 at
`secret/` → write the read-only ESO policy → ensure the ESO token + its
Kubernetes secret → apply the `ClusterSecretStore`.

**Behaviour by state:**
- Already initialised, unsealed, and the store is `Ready` → no-op.
- Initialised but configuration incomplete → prompts for the saved **root token**
  (never stored by this script) and re-applies the policy/token/store.
- Sealed (e.g. after a node reboot) → prompts for 3 unseal keys, then continues.

**Usage:** `mise run openbao:setup [environment]`. Run once after the first
deploy that includes OpenBao.

> The unseal keys and root token are shown **once** at initialisation and are
> never stored. Save them securely — they cannot be recovered.

---

## `metal/k3s/run.sh`

**Purpose:** Provisions a K3s cluster on bare-metal nodes via Ansible — SSH
setup, inventory decryption (SOPS), collection install, sysctl tuning, and the
K3s orchestration playbook. Decrypted inventory is cleaned up on exit.

**Usage:** `mise run provision [playbook]` (default `site`). Run first to
bootstrap the cluster.

---

## Workflow Summary

### 1. Bootstrap the cluster
```
mise run provision        ──>  K3s cluster
```

### 2. Initialise secrets
```
mise run secrets:init <env>      (interactive, auto-encrypts)
mise run secrets:check           (verify completeness)
```

### 3. Deploy services
```
mise run install
  ├── preflight.sh             (tools / plugins / cluster / secrets)
  ├── terraform apply          (provisions R2 bucket)
  ├── secrets/velero.sh        (reads outputs, writes velero.enc.yaml)
  └── helmfile sync            (all releases via principal helmfile)
```

### 4. Configure OpenBao (first deploy with OpenBao)
```
mise run openbao:setup <env>     (init + unseal + wire ESO; save the keys!)
```

### 5. Destroy an environment
```
mise run destroy <env>           ⚠️ deletes all PVs and storage
```

### Edit secrets manually
```
mise run secrets:decrypt <env> [chart]  ──>  edit .secrets.yaml  ──>  mise run secrets:encrypt <env> [chart]
```
