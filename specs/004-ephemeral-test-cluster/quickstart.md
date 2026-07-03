# Quickstart: Ephemeral test cluster + deep online BDD

Proves the isolated release tools work against a **real** Kubernetes API using a disposable cluster
and a hermetic `test` env — without touching `dev`/`prod`. See
[contracts/test-cluster-and-env.md](./contracts/test-cluster-and-env.md).

## Prerequisites

- `mise run setup` (pins `kind`, `helmfile`, `helm`, `kubectl`, `gum`, `jq`, `yq`, Python).
- A working **podman** runtime.

## Offline validation (no cluster, runs in CI)

```bash
mise run verify:offline
```

Expected: `@offline` scenarios pass, asserting `kind` is pinned, the `cluster:test:up`/`down` tasks
exist and target `kind-homelab-test`, and the `test` environment is declared. No cluster is created.

## Deep online validation (local, disposable cluster)

```bash
# 1. Create the throwaway cluster (dedicated context: kind-homelab-test)
mise run cluster:test:up

# 2. Deploy the hermetic test env, then run the real online scenarios
mise run verify          # @offline + @online (online only runs because the test context is reachable)

# 3. Tear it down
mise run cluster:test:down
```

Expected:

- `cluster:test:up` yields a reachable `kind-homelab-test` context; no `homelab-<env>` context is
  touched.
- The `test` releases sync with no external dependencies and no secrets.
- `install:one test <release> --yes` syncs one release and leaves a sibling unchanged.
- `destroy:one test <release> --yes` removes one release and leaves a sibling running.
- With no cluster, the `@online` scenarios **skip**; against a `homelab-<env>` context they **refuse**.

## Done when

- `mise run verify:offline` is green and cluster-free.
- After `cluster:test:up`, the `@online` install/destroy scenarios pass, each proving effect **and**
  sibling isolation.
- `cluster:test:down` removes the cluster and context; nothing is orphaned.
