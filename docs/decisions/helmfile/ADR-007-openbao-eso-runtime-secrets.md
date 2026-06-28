# ADR-007: OpenBao + External Secrets Operator for Runtime Secrets

- **Date**: 2026-06-20
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: infrastructure

## Context

This repository already manages secrets with SOPS: per-chart `.enc.yaml` files
committed under `helmfile/environments/<env>/secrets/`, decrypted at
`helmfile` render time and merged into release values (see ADR-005 and
[SECRETS.md](../../SECRETS.md)). That model works well for **bootstrap-time**
secrets — the values the platform's own helmfile needs in order to render and
deploy itself (SSO client secrets, Cloudflare tokens, the OpenBao deployment's
own configuration).

It does not cover **runtime** secrets: values that *workloads* need while
running, especially workloads in **downstream application repositories** built
on top of this platform (a portfolio site, a blog, custom services). Those repos
are intentionally separate from this one (see ADR-001 and the README), so they
cannot reach into this repo's SOPS files, and we do not want every downstream
app committing its own encrypted secrets and sharing the SOPS key.

What a downstream app needs is a **central secret store** plus a standard,
self-service way to consume secrets as ordinary Kubernetes objects — without
coupling the app to this platform's tooling. Forces at play:

- The platform is the foundation; downstream repos must depend on a stable,
  documented interface, not on SOPS internals.
- Secrets should have a single source of truth that can be rotated centrally.
- The consuming workload should not need to understand SOPS, helmfile, or Vault
  APIs — a plain `Secret` (env var / mounted file) is the lowest common
  denominator every chart already supports.
- The solution must be self-hostable and open-source (no managed cloud KMS, and
  no BSL-licensed software as a hard dependency).

## Decision

Deploy **OpenBao** as the cluster's runtime secret manager and the **External
Secrets Operator (ESO)** as the bridge that syncs OpenBao secrets into native
Kubernetes `Secret` objects.

- **OpenBao** (the OSI-licensed fork of HashiCorp Vault) runs standalone in
  `openbao-system` with a `file` storage backend on a Longhorn PVC, exposing a
  KV v2 engine at `secret/`.
- **ESO** runs in `external-secrets-system`. A cluster-scoped
  `ClusterSecretStore` (`external-secrets.io/v1`) named `openbao` points at
  OpenBao using token auth, backed by a read-only `eso-read` policy.
- Downstream repos consume secrets by creating `ExternalSecret` /
  `ClusterExternalSecret` resources that reference the `openbao` store; ESO
  materialises the requested keys into Kubernetes `Secret`s the workload mounts.

This establishes an explicit **boundary between the two secret systems**:

| | System | Scope |
|---|---|---|
| Bootstrap (render-time) | **SOPS** | Secrets this repo's helmfile needs to deploy itself |
| Runtime | **OpenBao + ESO** | Secrets consumed by workloads, including downstream repos |

The OpenBao **agent injector is disabled** (`injector.enabled: false`): delivery
is pull-based via ESO, not sidecar injection (see Alternatives). Post-deploy
initialisation (init, unseal, KV enable, ESO policy + token, `ClusterSecretStore`)
is automated and idempotent through `mise run openbao:setup` (see
[SCRIPTS.md](../../SCRIPTS.md)).

## Alternatives Considered

The decision has two axes: **which secret manager**, and **how secrets reach
workloads**. OpenBao was chosen as the manager over HashiCorp Vault (functionally
equivalent, but Vault is BSL-licensed; OpenBao is the Linux Foundation OSI fork)
and over a managed cloud KMS (rejected: this is a self-hosted homelab with no
cloud control plane in the critical path). The remaining options below concern
the delivery mechanism.

### Option A: SOPS only — no runtime store (status quo)
- **Description**: Keep using SOPS for everything; downstream repos manage their
  own encrypted secrets.
- **Pros**:
  - No new components to operate.
  - Secrets never live unencrypted at rest in etcd.
- **Cons**:
  - No central store; every downstream repo re-implements secret handling and
    must share the SOPS key.
  - No central rotation, no dynamic secrets, no runtime interface.
  - Couples downstream apps to this platform's tooling.

### Option B: OpenBao + agent injector (sidecar)
- **Description**: Use OpenBao's annotation-driven agent injector to mount
  secrets as files into an in-memory volume per pod.
- **Pros**:
  - Secrets stay out of etcd (tmpfs only) — smallest blast radius.
  - Native lease renewal / dynamic secrets without pod restarts.
- **Cons**:
  - A cluster-wide mutating webhook in the pod-admission path; if it breaks,
    scheduling is affected. (In practice its self-managed `caBundle` also
    conflicted with helm's server-side apply on upgrade.)
  - A sidecar per workload; apps must adopt the annotation/file-reading pattern.
  - Overkill for static KV secrets, which is all this platform needs today.

### Option C: OpenBao + CSI Secrets Store provider
- **Description**: Mount secrets as files via a CSI driver.
- **Pros**:
  - Secrets out of etcd, like the injector, without a per-pod mutating webhook.
- **Cons**:
  - Secrets are only available as mounted files, not as `Secret`s many charts
    expect for env vars.
  - Another DaemonSet/driver to operate; more than the current need requires.

### Option D: OpenBao + External Secrets Operator (Selected)
- **Description**: ESO pulls from OpenBao and writes native Kubernetes `Secret`s
  referenced by a `ClusterSecretStore`.
- **Pros**:
  - Workloads consume a plain `Secret` — zero coupling to OpenBao or this
    platform; the lowest common denominator every chart supports.
  - Declarative and GitOps-native: `ExternalSecret` CRs live in the downstream
    repo's git.
  - No per-pod sidecar and no admission webhook in the critical path.
  - Clean, documented interface for downstream repos.
- **Cons**:
  - Secrets are materialised into etcd as base64 `Secret`s (mitigable with etcd
    encryption-at-rest).
  - Another controller to operate; pull model is eventually consistent.
  - Env-var consumers need a restart to pick up rotated values.

## Consequences

### Positive
- **Stable interface for downstream repos**: apps depend only on the `openbao`
  `ClusterSecretStore` and standard `ExternalSecret`s, not on SOPS or this repo.
- **Central source of truth** for runtime secrets, rotatable in one place.
- **Open-source and self-hosted**: OpenBao is OSI-licensed; no managed KMS or BSL
  dependency.
- **Clear two-system boundary**: SOPS for bootstrap, OpenBao + ESO for runtime —
  documented in SECRETS.md and SCRIPTS.md.
- **No admission webhook / sidecar overhead**: pull-based delivery keeps the
  pod-admission path clean (the injector is disabled).
- **Repeatable setup**: `mise run openbao:setup` is idempotent and resumable;
  it never re-initialises or regenerates the unseal keys/root token.

### Negative
- **Runtime secrets live in etcd** as base64 `Secret`s — a larger blast radius
  than the injector's tmpfs-only model.
- **Operational surface grows**: OpenBao + ESO are two more components to run,
  monitor, and upgrade.
- **Manual key custody**: OpenBao initialisation produces unseal keys and a root
  token that are shown once and must be stored securely off-cluster.

### Risks
- **A node reboot leaves OpenBao sealed**, freezing every ESO-backed secret until
  it is manually unsealed.
  - *Mitigation*: evaluate auto-unseal (transit/static) — tracked in ROADMAP
    "OpenBao hardening".
- **Static ESO token** could leak or expire, breaking sync.
  - *Mitigation*: replace token auth with Kubernetes auth — tracked in ROADMAP.
- **Root token longevity**: a privileged token must exist for re-running setup,
  conflicting with revoking it after bootstrap.
  - *Mitigation*: documented as a hardening item; revisit once Kubernetes auth
    removes the need for the static token.
- **Secrets at rest in etcd**.
  - *Mitigation*: enable k3s `--secrets-encryption` — tracked in ROADMAP.

## References

- `helmfile/common/values/openbao.yaml.gotmpl` — OpenBao release values (file
  storage, KV, injector disabled)
- `helmfile/releases/004-core-apps.helmfile.yaml.gotmpl` — `openbao` and
  `external-secrets` releases
- `scripts/apps/setup-openbao.sh` — idempotent post-deploy setup (`mise run openbao:setup`)
- `scripts/lib/openbao.sh` — shared OpenBao / ESO identifiers
- [SECRETS.md](../../SECRETS.md) — SOPS bootstrap vs OpenBao runtime boundary
- [SCRIPTS.md](../../SCRIPTS.md) — setup and preflight scripts
- ADR-005 — per-environment config system; ADR-001 (project) — fork-based model
- ROADMAP "OpenBao hardening", "Secrets end-state ADR", and secret-delivery
  follow-ups
