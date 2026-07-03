# Phase 1 Data Model: Ephemeral test cluster + hermetic `test` env

No persistent storage. The entities are configuration objects and short-lived runtime views.

## Entities

### TestCluster (disposable)

A throwaway local Kubernetes cluster created per test run.

| Field | Value | Notes |
|-------|-------|-------|
| tool | `kind` | mise-pinned; podman provider. |
| name | `homelab-test` | kind cluster name. |
| context | `kind-homelab-test` | dedicated kube context; never a `homelab-<env>`. |
| lifetime | ephemeral | created by `cluster:test:up`, removed by `cluster:test:down`. |

### TestEnvironment (`test`)

A first-class Helmfile environment of trivial releases.

| Field | Value | Notes |
|-------|-------|-------|
| name | `test` | selected via `-e test`. |
| kubeContext | `kind-homelab-test` | so helmfile/helm target the disposable cluster. |
| releases | ≥2 trivial | dependency-free, secret-free (e.g. `charts/test-app`). |

### TestRelease (trivial)

| Field | Type | Notes |
|-------|------|-------|
| name | string | e.g. `test-a`, `test-b`. |
| namespace | string | e.g. `test`. |
| chart | string | local `charts/test-app` (ConfigMap/Deployment only). |
| version | string | pinned chart version. |
| needs | none | no cross-release dependencies. |

### OnlineOutcome (asserted)

| Action | Effect on target | Isolation invariant |
|--------|------------------|---------------------|
| `install:one test <t>` | target present at defined version | a sibling release unchanged |
| `destroy:one test <t>` | target absent | a sibling release still running |

## Rules

- The online scenarios act **only** on `TestRelease`s in the `test` env on `kind-homelab-test`.
- The cluster cross-check reads the **target env's** context (`kind-homelab-test` for `test`),
  not the active one.
- Any `homelab-<env>` context ⟹ online scenarios refuse/skip.
