# Quickstart: Isolated install/update of a single Helmfile release

Validation guide proving the feature works end-to-end. See [contracts/install-one-cli.md](./contracts/install-one-cli.md)
for the full interface and [data-model.md](./data-model.md) for the selectable-set rules.

## Prerequisites

- `mise run setup` has been run (pins `helmfile`, `helm`, `gum`, `jq`, `yq`, `kubectl`, Python).
- For `@online` checks only: a reachable `homelab-<env>` kube context.

## Offline validation (no cluster)

Runs in CI and pre-commit; proves wiring and the guard via stubs.

```bash
mise run verify:offline
```

Expected: the `isolated_release_install` `@offline` scenarios pass, asserting:

- the `install:one` mise task exists and is shaped like `destroy:one`;
- the shared `scripts/lib/helmfile.sh` provides `helmfile_installable_rows` and is sourced by
  `scripts/helm/install-one.sh`;
- running the script under stub tools never offers/syncs an unmanaged cluster release;
- a defined-but-undeployed release is labelled `install`; a defined-and-deployed release, `update`;
- `--dry-run` prints the preview and performs no `sync`;
- `--yes` without a release name is refused;
- syncing a selectable release invokes exactly `-l name=<release> sync --skip-deps`;
- blocking steps show a `gum` spinner.

## Manual smoke (interactive, against a dev cluster)

```bash
# 1. Preview only — no changes
mise run install:one dev <release> --dry-run

# 2. Interactive pick + confirm (each option tagged install/update)
mise run install:one dev

# 3. By name, with confirmation
mise run install:one dev <release>
```

Expected: only the chosen release is synced; no other release, Terraform state, or Velero secret is
touched.

## Online validation (local, needs a cluster)

```bash
mise run verify        # runs @offline + @online
```

Expected: the `@online` scenario syncs a throwaway release via the task and asserts sibling releases
are untouched.

## Done when

- `mise run verify:offline` passes with no cluster.
- A single managed release can be installed/updated by name and via the picker, with confirmation.
- An unmanaged release can never be synced (guard holds across all paths).
- `--dry-run` and a declined confirmation make zero changes.
