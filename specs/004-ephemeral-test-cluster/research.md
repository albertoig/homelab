# Phase 0 Research: Ephemeral test cluster + hermetic `test` env

All Technical Context unknowns are resolved below. No `NEEDS CLARIFICATION` remain.

## R1 — Ephemeral cluster tool

**Decision**: Use **`kind`**, pinned via `mise` (aqua backend `kubernetes-sigs/kind`), with the
**podman** provider (`KIND_EXPERIMENTAL_PROVIDER=podman`). A dedicated cluster name/context
`kind-homelab-test` isolates it from any homelab context.

**Rationale**: The host has **podman, not docker**. `kind` has the most mature podman support of the
options, starts fastest (~10–20s), and runs cleanly in GitHub Actions — keeping the door open to run
`@online` in CI later. It is a single static binary (aqua-pinnable) with no daemon of its own.

**Alternatives considered**:
- **minikube** (aqua `kubernetes/minikube`, `--driver=podman --rootless`): well-known and has a nice
  `--profile` model, but is heavier (~30–60s, full-node container) and its rootless-podman path is
  finicky (cgroups v2 delegation, occasional `--container-runtime=containerd`). Kept as a
  first-class swappable alternative.
- **k3d** (k3s parity with prod): wants docker; podman support relies on a socket shim and is flaky.
  Rejected for this host.

**Swappability**: The choice is isolated to one `.mise.toml` tool entry and the
`cluster:test:up`/`down` tasks; switching to minikube later is a local change with no impact on the
`test` env or the BDD steps (which only care that a reachable test context exists).

## R2 — Hermetic `test` environment

**Decision**: Add a `test` environment to `helmfile.yaml.gotmpl` whose releases come from a minimal
dedicated helmfile group of **trivial, dependency-free** charts. Use a tiny local chart (a bare
`ConfigMap`/`Deployment`) or a well-known dependency-light chart, with **no** `needs:` on
Longhorn/MetalLB/cert-manager, **no** SOPS secrets, and **no** Terraform. At least two releases so
isolation can be asserted.

**Rationale**: The production helmfile cannot sync on a bare cluster (storage/LB/DNS/secrets/TF
deps). A hermetic `test` env is the smallest thing that lets the isolated tools perform a **real**
sync/delete on the ephemeral cluster, fast and offline-of-secrets.

**Alternatives considered**: A separate standalone `tests/fixtures/helmfile.yaml` (rejected: the
tools resolve `-e <env>` against the principal `helmfile.yaml.gotmpl`, so a real `test` environment
keeps the code path identical to dev/prod); reusing dev releases (rejected: heavy external deps).

## R3 — Env-scoped cluster cross-check (the bug)

**Decision**: `scripts/lib/helmfile.sh` cluster helpers MUST query the target environment's kube
context. Resolve the context from the environment (e.g. the `kubeContext` the Helmfile declares per
environment) and pass it explicitly to `helm` (`--kube-context <ctx>`), rather than relying on the
active context.

**Rationale**: Today `helmfile_cluster_releases` runs a bare `helm list -A`, which reads whatever
context is active. If the operator's context ≠ the target env, install-vs-update labelling and the
unmanaged guard are wrong. `helmfile` already targets the env's `kubeContext` for sync/destroy, so
the cross-check must match.

**Alternatives considered**: Requiring the operator to pre-select the context (rejected: fragile,
and the tool already knows the env); deriving releases from `helmfile` status instead of `helm`
(rejected: changes the guard's data source).

## R4 — Online test lifecycle & safety

**Decision**: `@online` scenarios (a) skip unless a reachable **test** context is active, (b) refuse
any `homelab-<env>` context, (c) self-discover target + sibling from `helmfile -e test list` ∩
`helm list -A`, (d) run the real `install:one`/`destroy:one`, (e) assert effect + sibling isolation.
Cluster create/destroy is driven by the `cluster:test:up`/`down` mise tasks, invoked around the
online run (locally, or in CI); teardown is best-effort.

**Rationale**: Mirrors the existing offline harness (real script as subprocess) but against a real
API. The context guard makes it impossible to mutate homelab by accident, satisfying the safety
edge cases.

**Alternatives considered**: Having pytest create/destroy the cluster inside a fixture (viable, but
keeping create/destroy as explicit mise tasks matches the project's task-centric conventions and
lets CI cache/manage the cluster); hardcoding release names (rejected by FR-007).

## R5 — Test strategy (pytest-bdd, offline vs online)

**Decision**: Keep everything in pytest-bdd. The new `@online` scenarios live in the existing
`isolated_release_install.feature` / `isolated_release_delete.feature` (replacing the skip
placeholders) plus a small `ephemeral_test_cluster.feature` for the cluster/`test`-env wiring
(`@offline` file/task inspection + `@online` create/reach/delete). `@online` stays excluded from the
default `-m offline` CI run.

**Rationale**: One acceptance source of truth; the online layer extends the isolated tools' existing
features rather than duplicating them.
