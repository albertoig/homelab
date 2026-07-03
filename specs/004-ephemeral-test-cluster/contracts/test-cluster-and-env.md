# Contract: ephemeral test cluster + `test` environment + online BDD

Defines the interfaces this feature adds and the guarantees callers (maintainers, CI, the online
BDD) can rely on.

## Cluster lifecycle (mise tasks)

```text
mise run cluster:test:up      # create the disposable cluster
mise run cluster:test:down    # delete it
```

| Task | Guarantee |
|------|-----------|
| `cluster:test:up` | Creates a local cluster via the mise-pinned tool (kind, podman provider) with the dedicated context **`kind-homelab-test`**; waits until reachable; idempotent (safe to re-run). MUST NOT create/select/modify any `homelab-<env>` context. (FR-001/002/003) |
| `cluster:test:down` | Deletes the `kind-homelab-test` cluster and context; safe when nothing exists (no error). Best-effort so an interrupted run leaves nothing orphaned. |

Exit non-zero with a clear message when the tool/runtime is missing.

## `test` Helmfile environment

- Selected as `-e test`, resolved against the principal `helmfile.yaml.gotmpl` exactly like
  `dev`/`prod`. Declares `kubeContext: kind-homelab-test`.
- Contains **only trivial, dependency-free** releases (≥2): no Longhorn/MetalLB/cert-manager `needs:`,
  no SOPS secrets, no Terraform. (FR-004/005)
- `helmfile -e test list` enumerates exactly those releases; `helmfile -e test sync` deploys them on
  a bare cluster with no external dependency and no decryption.

## Online BDD contract

- `@online` scenarios for `install:one`, `destroy:one`, and the cluster/`test`-env wiring:
  - **Skip** (not fail) unless the `kind-homelab-test` context is reachable. (FR-008)
  - **Refuse** to run against any `homelab-<env>` context. (FR-008)
  - **Self-discover** target + sibling from `helmfile -e test list` ∩ `helm list -A`. (FR-007)
  - Perform the **real** action and assert effect **and** isolation:
    - install:one → target present at defined version; a sibling unchanged. (FR-006)
    - destroy:one → target gone; a sibling still running. (FR-006)
- Excluded from the default offline/CI run (`-m offline`); run via `mise run verify` (or a dedicated
  online task) after `cluster:test:up`. (FR-010)

## Shared library: env-scoped cross-check

- `helmfile_cluster_releases` / `helmfile_cluster_keys` MUST query the **target environment's** kube
  context (resolved from the env, e.g. `helm --kube-context <ctx> list -A`), not the active context.
  (FR-009)
- Offline stubs continue to satisfy this (the stub `helm` ignores the flag), so `@offline` stays
  green.

## Offline test harness additions

The `ephemeral_test_cluster` `@offline` scenarios assert (via file/TOML inspection, no cluster):

- `kind` is pinned in `.mise.toml [tools]`;
- `cluster:test:up` / `cluster:test:down` tasks exist and reference the test-only context;
- the `test` environment is declared in `helmfile.yaml.gotmpl` and points at `kind-homelab-test`.
