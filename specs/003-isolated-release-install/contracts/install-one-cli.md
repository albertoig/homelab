# Contract: `install:one` CLI / mise task

The feature's external interface is a mise task backed by a Bash script. This contract defines the
invocation surface, exit behavior, and the guarantees callers (operators and CI) can rely on. It
mirrors `destroy:one` (see specs/002) with `sync` in place of `destroy` and an install/update label.

## Invocation

```text
mise run install:one [<environment>] [<release>] [--dry-run] [--yes]
# direct (secondary): ./scripts/helm/install-one.sh [<environment>] [<release>] [--dry-run] [--yes]
```

### Arguments

| Arg | Required | Values | Meaning |
|-----|----------|--------|---------|
| `<environment>` | No | `dev` \| `prod` | Target env. Omitted → resolved via `lib/env.sh` (ENV var or interactive prompt). |
| `<release>` | No | release `name` or `namespace/name` | Release to sync. Omitted → `gum` picker of selectable releases. |

### Flags

| Flag | Meaning |
|------|---------|
| `--dry-run` | Print the target's name, namespace, chart, version, action (install/update) and any prerequisites; make no changes; exit 0. |
| `--yes` | Skip the interactive confirmation. Requires an explicit `<release>`. Prod-safety and the YAML/cluster guard still apply. |

## Behavioral contract

1. **Selectable set** = releases defined by `helmfile -e <env> list` (deployed or not). Only these
   may be targeted or appear in the picker. (FR-002)
2. **Action label**: cross-check `helm list -A` — present → `update`, absent → `install`. Labelling
   only; never the source of the selectable set. (FR-004)
3. **Unmanaged guard**: a release in the cluster but not in the Helmfile is never selectable or
   syncable, under any flag combination. (FR-003)
4. **Sync** targets exactly the one release via
   `helmfile -f helmfile.yaml.gotmpl -e <env> -l name=<release> sync --skip-deps` and runs **no**
   full-environment sync and no Terraform/Velero steps. (FR-006)
5. **Confirmation**: `gum confirm` unless `--yes`. Production always requires a deliberate
   confirmation. (FR-007)
6. **Prerequisite warning**: if the release declares `needs:`, they are listed before the sync
   proceeds. (FR-009)
7. **Ambiguity**: a bare name matching multiple selectable releases is refused with a request to
   qualify as `namespace/name`.
8. **Progress feedback**: whenever the task waits to fetch information or runs a long-running
   operation, it shows a `gum spin` spinner with a descriptive title. The screen is never a silent
   freeze. (FR-013)

## Exit codes

| Code | Condition |
|------|-----------|
| `0` | Release synced; or `--dry-run`; or no defined releases; or user aborted at picker/confirm. |
| `1` | Invalid env; unknown flag; `--yes` without a release; target not selectable (unmanaged/unknown); ambiguous name; cluster unreachable. |

## Stub contract (for `@offline` tests)

The `@offline` scenarios run the real script with a temporary PATH containing stub binaries:

- `helmfile … list --output json` → prints a canned DefinedRelease JSON array.
- `helm list -A --output json` → prints a canned ClusterRelease JSON array.
- `helmfile … build` → prints canned rendered YAML (for the `needs:` prerequisite check).
- `helmfile … -l name=<release> sync --skip-deps` → records its argv to a file and exits 0
  (installs nothing) so the test asserts the exact selector without mutating anything.
- `gum` → non-interactive stand-in (`confirm`→0, `choose`→first line, `spin`→exec wrapped cmd and
  records its title).

Guarantee under test: the sync stub is invoked **only** for selectable releases, **never** for
unmanaged ones, and **not at all** under `--dry-run`.
