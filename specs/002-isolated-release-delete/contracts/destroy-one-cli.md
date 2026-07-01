# Contract: `destroy:one` CLI / mise task

The feature's external interface is a mise task backed by a Bash script. This contract defines the
invocation surface, exit behavior, and the guarantees callers (operators and CI) can rely on.

## Invocation

```text
mise run destroy:one [<environment>] [<release>] [--dry-run] [--yes]
# direct (secondary): ./scripts/helm/destroy-one.sh [<environment>] [<release>] [--dry-run] [--yes]
```

### Arguments

| Arg | Required | Values | Meaning |
|-----|----------|--------|---------|
| `<environment>` | No | `dev` \| `prod` | Target env. Omitted → resolved via `lib/env.sh` (ENV var or interactive prompt). |
| `<release>` | No | release `name` or `namespace/name` | Release to delete. Omitted → `gum` picker of selectable releases. |

### Flags

| Flag | Meaning |
|------|---------|
| `--dry-run` | Print the target's name, namespace, chart, version (and any dependents); make no changes; exit 0. |
| `--yes` | Skip the interactive confirmation. Requires an explicit `<release>`. Prod-safety and the YAML/cluster guard still apply. |

## Behavioral contract

1. **Selectable set** = releases defined by `helmfile -e <env> list` **AND** present in
   `helm list -A`. Only these may be targeted or appear in the picker. (FR-002)
2. **Unmanaged guard**: a release in the cluster but not in the Helmfile is never selectable or
   deletable, under any flag combination. (FR-003)
3. **Undeployed target**: a defined-but-not-deployed name reports "nothing to delete" and exits 0
   without changes.
4. **Deletion** removes exactly the one release via
   `helmfile -f helmfile.yaml.gotmpl -e <env> -l name=<release> destroy --skip-deps` and runs
   **no** env-wide cleanup (no Longhorn/namespace finalizers, CRD removal, or Terraform). (FR-005)
5. **Confirmation**: default-deny `gum confirm` unless `--yes`. Production always requires a
   deliberate confirmation. (FR-006)
6. **Dependents warning**: if other releases declare `needs:` on the target, they are listed
   before deletion proceeds. (FR-008)
7. **Ambiguity**: a bare name matching multiple selectable releases is refused with a request to
   qualify as `namespace/name`. (R6)
8. **Progress feedback**: whenever the task waits to fetch information or runs a long-running
   operation, it shows a `gum spin` spinner with a descriptive title. The screen is never a silent
   freeze. (FR-013)

## Exit codes

| Code | Condition |
|------|-----------|
| `0` | Release deleted; or `--dry-run`; or nothing-to-delete; or user aborted at picker/confirm. |
| `1` | Invalid env; unknown flag; `--yes` without a release; target not selectable (unmanaged); ambiguous name; cluster unreachable. |

## Stub contract (for `@offline` tests)

The `@offline` scenarios run the real script with a temporary PATH containing stub binaries:

- `helmfile … list --output json` → prints a canned DefinedRelease JSON array.
- `helm list -A --output json` → prints a canned ClusterRelease JSON array.
- `helmfile … -l name=<release> destroy --skip-deps` → records its argv to a file and exits 0
  (uninstalls nothing) so the test asserts the exact selector without mutating anything.
- `gum` → non-interactive stand-in (`confirm`→0, `choose`→first line, `spin`→exec wrapped cmd).

Guarantee under test: the destroy stub is invoked **only** for selectable releases, **never** for
unmanaged or undeployed ones, and **not at all** under `--dry-run`.
