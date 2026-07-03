# Feature Specification: Ephemeral test cluster + hermetic `test` env for deep online BDD

**Feature Branch**: `feat/35-ephemeral-test-cluster`

**Created**: 2026-07-02

**Status**: Draft

**Input**: GitHub issue #35 — the isolated single-release tools (`install:one` #29, `destroy:one`
#30) are covered only by `@offline` pytest-bdd scenarios that run the real scripts under **stubbed**
`helmfile`/`helm`/`gum`. The `@online` scenarios are `pytest.skip()` placeholders, so nothing proves
a real `helmfile sync`/`destroy` works against a live Kubernetes API or that a single-release action
leaves siblings untouched. We want real "deep mode" BDD that drives a **disposable** cluster and a
hermetic `test` environment, so `dev`/`prod` are never touched.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spin up and tear down a disposable test cluster (Priority: P1)

As a maintainer, I run one command to create a throwaway local Kubernetes cluster and another to
delete it, so I can run destructive/mutating tests without any risk to the homelab `dev`/`prod`
clusters. The cluster tool is pinned by `mise` (no global install) and works with the host container
runtime (podman).

**Why this priority**: Every deep online test depends on having a disposable cluster; without it the
`@online` scenarios cannot run safely. This is the foundation.

**Independent Test**: Running the "up" command produces a reachable cluster with a dedicated,
recognisable kube context; running the "down" command removes it and its context; neither touches a
`homelab-<env>` context.

**Acceptance Scenarios**:

1. **Given** the pinned cluster tool, **When** I run the "up" task, **Then** a local cluster is
   created with a dedicated test context and `kubectl` can reach it.
2. **Given** a running test cluster, **When** I run the "down" task, **Then** the cluster and its
   context are removed.
3. **Given** any point in the flow, **When** the tasks run, **Then** no `homelab-dev`/`homelab-prod`
   context is created, selected, or modified.

### User Story 2 - A hermetic `test` environment the isolated tools can act on (Priority: P1)

As a maintainer, the repository provides a `test` environment whose releases are **trivial and
dependency-free** (no Longhorn/MetalLB/cert-manager/SOPS/Terraform), so the isolated tools can
actually install/update/delete real releases on the ephemeral cluster without the full homelab
stack.

**Why this priority**: The real `helmfile.yaml.gotmpl` cannot sync on a bare cluster; a minimal
`test` env is what makes real online runs possible and fast.

**Independent Test**: `helmfile -e test list` enumerates only the trivial release(s); syncing them
onto the ephemeral cluster succeeds with no external dependencies and no secret decryption.

**Acceptance Scenarios**:

1. **Given** the `test` environment, **When** I list its releases, **Then** it contains only
   trivial, dependency-free release(s) intended for testing.
2. **Given** an ephemeral cluster, **When** the `test` releases are synced, **Then** they deploy
   successfully without any external dependency or secret.

### User Story 3 - Deep `@online` BDD for install:one and destroy:one (Priority: P1)

As a maintainer, the `@online` scenarios for `install:one` and `destroy:one` run against the
ephemeral cluster and the `test` environment, performing the **real** sync/delete and asserting the
action's effect **and its isolation** (siblings untouched), so I know the tools work end-to-end
against a real Kubernetes API.

**Why this priority**: This is the actual goal of the issue — real proof, not stub proof.

**Independent Test**: With an ephemeral `test` cluster up, the `@online` `install:one` scenario syncs
one release and leaves a sibling unchanged; the `@online` `destroy:one` scenario deletes one release
and leaves a sibling running. Both self-discover their targets (no hardcoded release names).

**Acceptance Scenarios**:

1. **Given** an ephemeral cluster with the `test` releases deployed, **When** `install:one` syncs one
   release, **Then** that release is present at the version the Helmfile defines and a sibling
   release is unchanged.
2. **Given** an ephemeral cluster with the `test` releases deployed, **When** `destroy:one` deletes
   one release, **Then** that release is gone and a sibling release still runs.
3. **Given** no reachable cluster or a non-test context, **When** the `@online` scenarios are
   collected, **Then** they **skip** cleanly rather than fail (they never run against homelab).

### User Story 4 - Correct env-scoped cluster cross-check (Priority: P2)

As a maintainer, the shared selection library cross-checks the cluster using the **target
environment's** kube context (`homelab-<env>` / the test context), not whatever context happens to be
active, so install-vs-update labelling and the unmanaged guard are correct regardless of the
operator's current context.

**Why this priority**: A latent correctness bug surfaced by #35: the cross-check currently reads the
active context. It must be fixed for the online tests (and real use) to be trustworthy.

**Independent Test**: With the active context pointing at env A but the task targeting env B, the
cluster cross-check reflects env B's releases, not env A's.

**Acceptance Scenarios**:

1. **Given** an active context that differs from the target environment, **When** the tool computes
   the selectable/action set, **Then** it queries the target environment's context, not the active
   one.

### Edge Cases

- **No container runtime / tool missing**: the up task fails with a clear message; `@online`
  scenarios skip.
- **Cluster already exists**: the up task is idempotent (reuses or recreates cleanly); the down task
  is safe to run when nothing exists.
- **Online run interrupted**: teardown is best-effort so a failed run does not leave an orphaned
  cluster blocking the next run.
- **Wrong context safety**: `@online` scenarios must refuse to run against any `homelab-<env>`
  context — only the dedicated test context.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An ephemeral local Kubernetes cluster tool MUST be pinned via `mise` (no global
  install) and MUST work with the host container runtime (podman).
- **FR-002**: The repo MUST provide `mise` tasks to create and delete the test cluster
  (`cluster:test:up` / `cluster:test:down`), producing a dedicated, clearly-named test kube context.
- **FR-003**: The cluster tasks MUST NOT create, select, or modify any `homelab-<env>` context, and
  MUST NOT touch the real dev/prod clusters.
- **FR-004**: The repo MUST provide a `test` Helmfile environment whose releases are trivial and
  **dependency-free** — no Longhorn/MetalLB/cert-manager/SOPS/Terraform and no secret decryption —
  suitable for syncing onto a bare ephemeral cluster.
- **FR-005**: The `test` environment MUST define at least two releases so isolation (acting on one,
  leaving the other) can be asserted.
- **FR-006**: `@online` pytest-bdd scenarios for `install:one` and `destroy:one` MUST perform the
  **real** sync/delete against the ephemeral cluster and `test` env, and MUST assert both the
  action's effect and its isolation (a sibling release is unchanged).
- **FR-007**: The `@online` scenarios MUST self-discover their target and sibling releases from the
  Helmfile/cluster state (no hardcoded release names).
- **FR-008**: The `@online` scenarios MUST **skip** (not fail) when no reachable test cluster/context
  is present, and MUST refuse to run against any `homelab-<env>` context.
- **FR-009**: The shared selection library MUST cross-check the cluster using the **target
  environment's** kube context, not the active context, so labelling and the guard are correct.
- **FR-010**: The `@offline` suite MUST remain green and cluster-free; `@online` MUST stay excluded
  from the default offline/CI run (`-m offline`) unless an ephemeral cluster is explicitly provided.
- **FR-011**: The workflow (create cluster → run online → tear down) MUST be documented for
  operators (`docs/`), alongside the existing verify tasks.

### Key Entities

- **Test cluster**: a disposable local Kubernetes cluster created per test run, addressed by a
  dedicated kube context; never a homelab cluster.
- **Test environment**: a `test` Helmfile environment of trivial, dependency-free releases, the only
  releases the online scenarios act on.
- **Online scenario**: a pytest-bdd `@online` scenario that drives the real isolated tool against the
  test cluster and asserts effect + isolation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A maintainer can create a working test cluster and delete it with two `mise` commands,
  with zero effect on `dev`/`prod`.
- **SC-002**: The `test` environment syncs onto a fresh ephemeral cluster with no external
  dependencies and no secrets in under a minute.
- **SC-003**: The `@online` `install:one` and `destroy:one` scenarios pass against the ephemeral
  cluster, each proving the action's effect **and** that a sibling release is untouched.
- **SC-004**: The `@online` scenarios skip cleanly with no cluster and never run against a
  `homelab-<env>` context.
- **SC-005**: The `@offline` suite remains green and cluster-free.
- **SC-006**: The cluster cross-check reflects the target environment's context, not the active one,
  in 100% of runs.

## Assumptions

- The host has a working container runtime (podman) able to back the chosen ephemeral cluster tool.
- The chosen tool (kind vs minikube vs k3d) is an implementation decision recorded in research.md;
  the spec only requires "an ephemeral local cluster, pinned via mise, podman-compatible", so the
  choice is swappable via one tool entry + the up/down tasks.
- This feature validates the **isolated tooling against a real Kubernetes API**, not that the full
  homelab stack installs — the full stack remains covered by `mise run install` against `dev`.
- Distro parity is not required: the ephemeral tool may use upstream Kubernetes even though prod runs
  k3s; testing `install:one`/`destroy:one` mechanics does not depend on the distro.
- The isolated tools (`install:one` #29, `destroy:one` #30) and the shared `scripts/lib/helmfile.sh`
  already exist; this feature adds the cluster/test-env/online-BDD layer and the context fix.
