# Quickstart: Isolated delete of a single Helmfile release

Validation guide proving the feature works end-to-end. See [contracts/destroy-one-cli.md](./contracts/destroy-one-cli.md)
for the full interface and [data-model.md](./data-model.md) for the selectable-set rules.

## Prerequisites

- `mise run setup` has been run (pins `helmfile`, `helm`, `gum`, `jq`, `yq`, `kubectl`, Python).
- For `@online` checks only: a reachable `homelab-<env>` kube context.

## Offline validation (no cluster)

Runs in CI and pre-commit; proves wiring and the guard via stubs.

```bash
mise run verify:offline
```

Expected: the `isolated_release_delete` `@offline` scenarios pass, asserting:

- the `destroy:one` mise task exists and is shaped like `destroy`;
- the shared `scripts/lib/helmfile.sh` helper exists and is sourced by `scripts/helm/destroy-one.sh`;
- running the script under stub tools never offers/deletes an unmanaged cluster release;
- `--dry-run` prints the preview and performs no `destroy`;
- `--yes` without a release name is refused;
- deleting a selectable release invokes exactly `-l name=<release> destroy --skip-deps`.

## Manual smoke (interactive, against a dev cluster)

```bash
# 1. Preview only — no changes
mise run destroy:one dev <release> --dry-run

# 2. Interactive pick + confirm
mise run destroy:one dev

# 3. By name, with confirmation
mise run destroy:one dev <release>
```

Expected: only the chosen release is uninstalled; siblings keep running; no namespaces, CRDs,
PersistentVolumes of other releases, or Terraform state are touched.

## Online validation (local, needs a cluster)

```bash
mise run verify        # runs @offline + @online
```

Expected: the `@online` scenario installs/targets a throwaway release, deletes it via the task,
and asserts sibling releases survive and no env-wide resources were removed.

## Done when

- `mise run verify:offline` passes with no cluster.
- A single managed release can be deleted by name and via the picker, with confirmation.
- An unmanaged or undeployed release can never be deleted (guard holds across all paths).
- `--dry-run` and a declined confirmation make zero changes.
