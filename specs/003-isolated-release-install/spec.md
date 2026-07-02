# Feature Specification: Isolated install/update of a single Helmfile release

**Feature Branch**: `feat/29-isolated-helmfile-install-script`

**Created**: 2026-07-01

**Status**: Draft

**Input**: GitHub issue #29 — "Add isolated install/update script for a single helmfile release (by name)".
Operators need to install or update **one** Helmfile-managed release in isolation — selected by name
— instead of syncing the whole environment with the existing `install` flow. It generalises the
one-off command run by hand (`helmfile -e prod -l name=openbao sync --skip-deps`). The capability
must be centralized as a `mise` task (`mise run install:one <env> [release]`), mirroring the sibling
`destroy:one` task, and must never touch a release that the Helmfile does not define, even if it is
running in the cluster.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Safely install/update one managed release by name (Priority: P1)

As a homelab operator, I run `mise run install:one <env> <release>` to sync a single
Helmfile-managed release, so I can install a new component or roll out a change to one component
without syncing the rest of the environment. The set of releases I am allowed to target is exactly
the set the Helmfile **defines** for that environment (the source of truth) — whether or not the
release is currently deployed. The cluster is cross-checked only to label the action: a defined
release that is **not** deployed is an **install**; one that **is** deployed is an **update**. A
release running in the cluster but **not** defined in the Helmfile is never targetable.

**Why this priority**: This is the core of issue #29 and the MVP. Without by-name sync plus the
YAML-as-source-of-truth guard there is no feature — and the guard is what makes it safe to ship.

**Independent Test**: With only this story done, an operator can sync a single defined release by
name (installing it if absent, updating it if present); attempting to target a release that is not
defined in the Helmfile is refused with a clear message; and no other release is synced.

**Acceptance Scenarios**:

1. **Given** a release defined in the Helmfile for `<env>` but **not** deployed, **When** I run
   `mise run install:one <env> <release>` and confirm, **Then** that release is synced as an
   **install** and no other release is touched.
2. **Given** a release defined in the Helmfile for `<env>` **and** already deployed, **When** I run
   the task and confirm, **Then** that release is synced as an **update**.
3. **Given** a release name that exists in the cluster but is **not** defined in the Helmfile,
   **When** I target it, **Then** the task refuses and explains it is not a managed release.
4. **Given** any sync, **When** it runs, **Then** only the single selected release is synced (no
   full-environment sync, and no Terraform/Velero-secret steps run).

### User Story 2 - Pick a release interactively (Priority: P2)

As an operator who does not remember exact release names, I run `mise run install:one <env>`
without a release argument and choose from a `gum` picker that lists every selectable release,
each annotated with the action (`install` or `update`) that will be performed.

**Why this priority**: Improves ergonomics and reduces typos targeting the wrong thing, but the
by-name path (US1) already delivers the core value.

**Independent Test**: Running the task with no release argument shows a picker containing exactly
the defined releases (deployed or not), each tagged install/update, and nothing that is unmanaged;
selecting one proceeds to the same confirm-and-sync flow as US1; cancelling changes nothing.

**Acceptance Scenarios**:

1. **Given** several defined releases (some deployed, some not), **When** I run the task with no
   release argument, **Then** I am offered a picker listing exactly those releases, each showing
   whether it is an install or an update.
2. **Given** a release running in the cluster but not defined in the Helmfile, **When** I open the
   picker, **Then** it is **not** offered.
3. **Given** the picker, **When** I cancel it, **Then** nothing is synced.
4. **Given** the task is waiting to fetch information or running a long operation, **When** I run
   it, **Then** a `gum` spinner is shown so the run is never a silent, frozen screen that looks hung.

### User Story 3 - Preview and prerequisite awareness before syncing (Priority: P2)

As a cautious operator, before I confirm a sync I want to see what I am about to install/update
(release, namespace, chart, version, action) and be warned if the release declares a `needs:`
prerequisite, so I do not roll out something whose dependencies are not in place. A `--dry-run`
shows this preview and exits without changing anything.

**Why this priority**: Prevents surprises, especially on prod, but the core sync (US1) functions
without it.

**Independent Test**: `--dry-run` prints the release's name, namespace, chart, version, and action
and makes no cluster change; when the release declares a `needs:`, the preview lists those
prerequisites as a warning.

**Acceptance Scenarios**:

1. **Given** a selectable release, **When** I run the task with `--dry-run`, **Then** I see its
   name, namespace, chart, version, and action and the cluster is unchanged.
2. **Given** a release that declares a `needs:` on another release, **When** I target it, **Then**
   those prerequisites are listed as a warning before I confirm.

### User Story 4 - Non-interactive install/update for automation (Priority: P2)

As the future CI pipeline (issue #28), I run `mise run install:one <env> <release> --yes` to sync a
release without an interactive prompt, while the safety guards still apply: the
YAML-and-cluster selectability guard is enforced, and production still requires explicit,
deliberate confirmation rather than a silent sync.

**Why this priority**: Enables automation but must not weaken the guards; depends on US1 first.

**Independent Test**: With `--yes` and an explicit release name, a selectable non-prod release is
synced without prompting; `--yes` with no release name is refused; the YAML/cluster guard still
blocks unmanaged releases; prod still demands explicit confirmation.

**Acceptance Scenarios**:

1. **Given** `--yes` and an explicit, selectable, non-prod release, **When** I run the task,
   **Then** it syncs without an interactive prompt.
2. **Given** `--yes` without a release name, **When** I run the task, **Then** it refuses (cannot
   auto-pick in non-interactive mode).
3. **Given** `--yes` targeting an unmanaged cluster release, **When** I run the task, **Then** it is
   still refused by the guard.
4. **Given** `--yes` targeting a selectable release in **prod**, **When** I run the task, **Then**
   an explicit confirmation is still required.

### User Story 5 - Shared selection library reused from destroy-one (Priority: P3)

As a maintainer, the "releases the Helmfile defines, cross-checked against the cluster, excluding
unmanaged ones" logic lives in the same reusable `scripts/lib/helmfile.sh` helper that
`destroy-one` already uses, so both isolated tools share one guard instead of duplicating it.

**Why this priority**: Reduces duplication and divergence risk across #29/#30, but is an internal
quality concern, not user-visible behavior.

**Independent Test**: The selectability/guard logic for install-one is provided by
`scripts/lib/helmfile.sh` (the same file destroy-one consumes), and the entry script sources it
rather than re-implementing the guard inline.

### Edge Cases

- **Undeployed defined release**: defined in YAML, not in the cluster → selectable as an
  **install** (this is the primary new behavior vs. destroy-one).
- **Unmanaged cluster release**: running but not in YAML → never selectable, never syncable — the
  central safety guard.
- **Ambiguous bare name**: a bare name mapping to more than one release (same name in different
  namespaces) → the task must not guess; it asks the operator to qualify with `namespace/name`.
- **Cluster unreachable**: if the cluster cannot be queried, the task fails with a clear message
  rather than assuming an empty target set.
- **No defined releases**: nothing defined for the env → the task says so and exits without a picker.
- **Aborted confirmation/picker**: cancelling either leaves the cluster unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The capability MUST be centralized as a `mise` task named `install:one` that accepts
  the target environment and an optional release argument, mirroring the sibling `destroy:one`
  task. Direct script invocation MAY remain possible, but `mise run` is the documented entry point.
- **FR-002**: The set of selectable releases MUST be the releases the Helmfile defines for the
  environment (the source of truth, e.g. `helmfile list`). This set is **independent of whether a
  release is deployed** — install-one may install a not-yet-deployed release or update a deployed
  one.
- **FR-003**: A release that exists in the cluster but is **not** defined in the Helmfile MUST NOT
  be selectable or syncable through this task, under any flag combination.
- **FR-004**: The cluster (`helm list -A`) MUST be cross-checked to label each target's action:
  defined-and-deployed → **update**, defined-and-not-deployed → **install**. This labelling MUST
  NOT be the source of the selectable set.
- **FR-005**: When no release argument is given, the task MUST present a `gum` picker containing
  exactly the selectable releases, each annotated with its install/update action.
- **FR-006**: The sync MUST target only the single selected release (via the Helmfile label
  selector mechanism, `-l name=<release> sync --skip-deps`) and MUST NOT run a full-environment
  sync or any environment-wide steps (Terraform, Velero secrets).
- **FR-007**: The sync MUST require confirmation by default (`gum confirm`), and production syncs
  MUST require deliberate confirmation per the project's prod safety principle and the conventions
  in `scripts/helm/install.sh`.
- **FR-008**: A `--dry-run` mode MUST show the target release's name, namespace, chart, version, and
  action and exit without changing the cluster.
- **FR-009**: When the target release declares a `needs:` prerequisite, the task MUST warn and list
  those prerequisites before the sync proceeds.
- **FR-010**: A `--yes` non-interactive mode MUST skip the interactive prompt while still enforcing
  the prod-safety guard and the YAML/cluster selectability guard; it MUST require an explicit
  release name (it MUST NOT auto-pick).
- **FR-011**: The selection/guard logic MUST live in the shared `scripts/lib/helmfile.sh` helper
  (the same one `destroy-one` consumes), and the implementation MUST reuse the existing shared
  helpers (`scripts/lib/env.sh`, `scripts/lib/colors.sh`, `scripts/lib/header.sh`) and `gum`, per
  the Bash+gum scripting principle.
- **FR-012**: Acceptance criteria MUST be authored as `pytest-bdd` Gherkin scenarios under
  `tests/features/`, each tagged exactly one of `@offline` (wiring + guard verified via file
  inspection and by running the script under stubbed `helmfile`/`helm`/`gum`/`kubectl`) or
  `@online` (real sync against a cluster).
- **FR-013**: Whenever the task waits to fetch information or perform a long-running operation, it
  MUST show a `gum` spinner with a descriptive title. The run MUST NOT present a silent, frozen
  screen, which is indistinguishable from a hang.

### Key Entities

- **Helmfile release**: a single deployable unit defined in `helmfile/releases/*` with a name,
  namespace, chart, version, labels, and optional `needs:` prerequisites. The Helmfile definition
  is the source of truth for what may be managed.
- **Cluster release**: a Helm release actually installed in the cluster (`helm list -A`), used only
  to label a target as install-vs-update; never as the source of the selectable set.
- **Selectable release**: a release defined in the Helmfile for the environment — the only releases
  this task may act on. Its **action** is `update` if it is present in the cluster, else `install`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can install or update one managed release by name with a single `mise run`
  command and one confirmation, without syncing any other release.
- **SC-002**: 100% of cluster releases that are not defined in the Helmfile are non-selectable and
  non-syncable through this task, across interactive, by-name, and `--yes` paths.
- **SC-003**: `--dry-run` produces the release preview and makes zero changes to the cluster in
  100% of runs.
- **SC-004**: The offline acceptance scenarios for this feature pass with no cluster access
  (`mise run verify:offline`).
- **SC-005**: A production sync never proceeds without an explicit, deliberate confirmation.
- **SC-006**: A defined-but-undeployed release can be installed by name/picker (labelled `install`),
  and a defined-and-deployed release is labelled `update`.

## Assumptions

- The active kube context follows the existing `homelab-<env>` convention and is selected via
  `scripts/lib/env.sh` (argument, `ENV` var, or interactive prompt), as in `install`/`destroy`.
- `helmfile`, `helm`, `gum`, `jq`, and `yq` are available via the pinned `mise` toolchain.
- The Helmfile auto-injects a `name` label per release so the `-l name=<release>` selector resolves
  a single release for the sync. Disambiguating a bare name that maps to multiple releases across
  namespaces is handled by asking the operator to qualify it; hardening that selector match is
  deferred scope (shared with #30).
- `--dry-run` shows a metadata preview (not a full `helmfile diff`); a richer diff-based preview is
  a deferred refinement.
- The shared selection helper already exists (added by #30); this feature reuses and extends it
  with the install-set helpers rather than duplicating the guard.
