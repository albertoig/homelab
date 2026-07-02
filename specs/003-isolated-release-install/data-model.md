# Phase 1 Data Model: Isolated install/update of a single Helmfile release

This feature has no persistent storage. The "entities" are in-memory views derived from `helmfile`
and `helm` output during a single run.

## Entities

### DefinedRelease (source of truth)

A release the Helmfile declares for the target environment. Sourced from
`helmfile -e <env> list --output json`.

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Helm release name. |
| `namespace` | string | Empty/absent → defaulted to `default` for keying. |
| `chart` | string | Chart reference (`repo/chart`). |
| `version` | string | Pinned chart version. |
| `labels` | string | Helmfile labels; the implicit `name` label drives the sync selector. |

### ClusterRelease (cross-check only)

A Helm release actually installed in the cluster. Sourced from `helm list -A --output json`.

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Installed release name. |
| `namespace` | string | Installed namespace. |
| `status` | string | e.g. `deployed`; informational. |

> ClusterRelease is **never** the source of the selectable set. It only supplies the install/update
> label and the unmanaged guard.

### SelectableRelease (derived)

The only releases this task may act on. Every DefinedRelease is selectable; the cluster decides the
action.

| Field | Type | Derivation |
|-------|------|------------|
| `key` | string | `"<namespace>/<name>"`. |
| `name` | string | From DefinedRelease. |
| `namespace` | string | From DefinedRelease (defaulted). |
| `chart` | string | From DefinedRelease (for preview). |
| `version` | string | From DefinedRelease (for preview). |
| `action` | enum | `update` if key ∈ ClusterRelease keys, else `install`. |
| `requires` | string[] | `namespace/name` of releases this key lists in `needs:` (advisory). |

## Derivation rules

- **Selectable** ⟺ key ∈ DefinedRelease keys (deployed or not).
- **Action** = `update` if key ∈ ClusterRelease keys, else `install` (FR-004).
- **Unmanaged** (in cluster, not defined) ⟹ excluded from Selectable; never syncable (FR-003).
- **Unknown** (neither defined nor in cluster) ⟹ refused as not a defined release.
- **Ambiguous bare name** ⟹ a release name mapping to >1 Selectable key requires the operator to
  qualify with `namespace/name`.

## State transitions

A selected release moves through: `selectable → previewed → confirmed → synced`. `--dry-run` stops
at `previewed`. A declined confirmation or cancelled picker stops before `confirmed`, leaving the
cluster unchanged. No other release changes state.
