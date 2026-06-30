# Phase 1 Data Model: Isolated delete of a single Helmfile release

This feature has no persistent storage. The "entities" are in-memory views derived from
`helmfile` and `helm` output during a single run.

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
| `labels` | string | Helmfile labels; the implicit `name` label drives the delete selector. |

### ClusterRelease (cross-check only)

A Helm release actually installed in the cluster. Sourced from `helm list -A --output json`.

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Installed release name. |
| `namespace` | string | Installed namespace. |
| `status` | string | e.g. `deployed`; informational. |

> ClusterRelease is **never** the source of the selectable set. It only confirms presence.

### SelectableRelease (derived)

The only releases this task may act on. Computed as the intersection of DefinedRelease and
ClusterRelease keyed on `namespace/name`.

| Field | Type | Derivation |
|-------|------|------------|
| `key` | string | `"<namespace>/<name>"`. |
| `name` | string | From DefinedRelease. |
| `namespace` | string | From DefinedRelease (defaulted). |
| `chart` | string | From DefinedRelease (for preview). |
| `version` | string | From DefinedRelease (for preview). |
| `dependents` | string[] | `namespace/name` of releases whose `needs:` references this `key` (advisory). |

## Derivation rules

- **Selectable** ⟺ key ∈ DefinedRelease keys **AND** key ∈ ClusterRelease keys.
- **Unmanaged** (in cluster, not defined) ⟹ excluded from Selectable; never deletable (FR-003).
- **Undeployed** (defined, not in cluster) ⟹ excluded from Selectable; targeting it reports
  "nothing to delete" and exits success (US1 scenario 3).
- **Ambiguous bare name** ⟹ a release name that maps to >1 Selectable key requires the operator
  to qualify with `namespace/name` (R6).

## State transitions

A selected release moves through: `selectable → previewed → confirmed → destroyed`.
`--dry-run` stops at `previewed`. A declined confirmation or cancelled picker stops before
`confirmed`, leaving the cluster unchanged. No other release changes state.
