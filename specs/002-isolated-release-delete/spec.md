# Feature Specification: Isolated delete of a single Helmfile release

**Feature Branch**: `feat/30-isolated-helmfile-delete-script`

**Created**: 2026-06-29

**Status**: Draft

**Input**: GitHub issue #30 — "Add isolated delete script for a single helmfile release (by name)".
Operators need to uninstall **one** Helmfile-managed release in isolation — selected by name —
instead of tearing down the whole environment with the existing `destroy` flow. The capability
must be centralized as a `mise` task (`mise run destroy:one <env> [release]`), mirroring the
existing `install`/`destroy` tasks, and must never be able to touch a release that the Helmfile
does not define, even if it is running in the cluster.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Safely delete one managed release by name (Priority: P1)

As a homelab operator, I run `mise run destroy:one <env> <release>` to uninstall a single
Helmfile-managed release, so I can remove or recycle one component without destroying the rest
of the environment. The set of releases I am allowed to delete is the **intersection** of what
the Helmfile defines for that environment (the source of truth) and what is actually deployed in
the cluster. A release that is running in the cluster but is **not** defined in the Helmfile is
never deletable through this task.

**Why this priority**: This is the core of issue #30 and the MVP. Without the by-name deletion
plus the YAML-as-source-of-truth guard there is no feature — and the guard is what makes it safe
enough to ship.

**Independent Test**: With only this story done, an operator can delete a single defined,
deployed release by name; attempting to delete a release that is undeployed or not defined in the
Helmfile is refused with a clear message; and no other release, namespace, or volume is affected.

**Acceptance Scenarios**:

1. **Given** a release that is defined in the Helmfile for `<env>` **and** deployed in the
   cluster, **When** I run `mise run destroy:one <env> <release>` and confirm, **Then** only that
   release is uninstalled and every other release stays running.
2. **Given** a release name that exists in the cluster but is **not** defined in the Helmfile,
   **When** I target it, **Then** the task refuses to delete it and explains it is not a managed
   release.
3. **Given** a name that is defined in the Helmfile but **not** currently deployed, **When** I
   target it, **Then** the task reports there is nothing to delete and makes no changes.
4. **Given** any deletion, **When** it runs, **Then** the environment-wide cleanup steps
   (Longhorn finalizers, namespace finalizers, CRD removal, Terraform destroy) are **not** run.

### User Story 2 - Pick a release interactively (Priority: P2)

As an operator who does not remember exact release names, I run `mise run destroy:one <env>`
without a release argument and choose from a `gum` picker that lists only the selectable
(defined-and-deployed) releases.

**Why this priority**: Improves ergonomics and reduces the chance of typos targeting the wrong
thing, but the by-name path (US1) already delivers the core value.

**Independent Test**: Running the task with no release argument shows a picker containing exactly
the selectable releases and nothing that is unmanaged or undeployed; selecting one proceeds to
the same confirm-and-delete flow as US1; cancelling the picker changes nothing.

**Acceptance Scenarios**:

1. **Given** several defined-and-deployed releases, **When** I run the task with no release
   argument, **Then** I am offered a picker listing exactly those releases.
2. **Given** the picker, **When** I cancel it, **Then** no release is deleted.

### User Story 3 - Preview and dependency awareness before deleting (Priority: P2)

As a cautious operator, before I confirm a deletion I want to see what I am about to remove
(release, namespace, chart, version) and be warned if other releases declare a `needs:`
dependency on it, so I do not silently break a dependent. A `--dry-run` shows this preview and
exits without changing anything.

**Why this priority**: Prevents accidental breakage, especially on prod, but the core deletion
(US1) functions without it.

**Independent Test**: `--dry-run` prints the release's name, namespace, chart, and version and
makes no cluster change; when other releases depend on the target, the preview/confirmation lists
those dependents as a warning.

**Acceptance Scenarios**:

1. **Given** a selectable release, **When** I run the task with `--dry-run`, **Then** I see its
   name, namespace, chart, and version and the cluster is unchanged.
2. **Given** a release that other releases declare a `needs:` on, **When** I target it, **Then**
   the dependents are listed as a warning before I confirm.

### User Story 4 - Non-interactive deletion for automation (Priority: P2)

As the future CI pipeline (issue #28), I run `mise run destroy:one <env> <release> --yes` to
delete a release without an interactive prompt, while the safety guards still apply: the
YAML-and-cluster selectability guard is enforced, and production still requires explicit,
deliberate confirmation rather than a silent delete.

**Why this priority**: Enables automation but must not weaken the guards; depends on US1 being in
place first.

**Independent Test**: With `--yes` and an explicit release name, a selectable non-prod release is
deleted without prompting; `--yes` with no release name is refused; the YAML/cluster guard still
blocks unmanaged releases; prod still demands explicit confirmation.

**Acceptance Scenarios**:

1. **Given** `--yes` and an explicit, selectable, non-prod release, **When** I run the task,
   **Then** it deletes without an interactive prompt.
2. **Given** `--yes` without a release name, **When** I run the task, **Then** it refuses
   (cannot auto-pick in non-interactive mode).
3. **Given** `--yes` targeting an unmanaged cluster release, **When** I run the task, **Then** it
   is still refused by the guard.

### User Story 5 - Shared selection library reused by install-one (Priority: P3)

As a maintainer, the "list releases that are defined in YAML ∩ present in the cluster, excluding
unmanaged ones" logic lives in one reusable shared-library helper, so the sibling isolated
install/update feature (#29) reuses the exact same guard instead of duplicating it.

**Why this priority**: Reduces duplication and divergence risk across #29/#30, but is an internal
quality concern, not user-visible behavior.

**Independent Test**: The selectability/guard logic is provided by a `scripts/lib/` helper that
both the delete-one and install-one entry points consume, and it is covered by its own tests.

**Acceptance Scenarios**:

1. **Given** the implementation, **When** inspected, **Then** the selection/guard logic resides
   in a shared `scripts/lib/` helper rather than inline in the delete-one script.

### Edge Cases

- **Undeployed defined release**: defined in YAML but not in the cluster → reported as "nothing
  to delete", exit success, no changes (see US1 scenario 3).
- **Unmanaged cluster release**: running but not in YAML → never selectable, never deletable
  (US1 scenario 2) — this is the central safety guard.
- **Ambiguous bare name**: a bare name that maps to more than one release (same name in different
  namespaces) → the task must not guess; it asks the operator to qualify with `namespace/name`.
- **Cluster unreachable**: if the cluster cannot be queried, the task fails with a clear message
  rather than assuming an empty selectable set.
- **No selectable releases**: nothing defined-and-deployed → the task says so and exits without a
  picker.
- **Aborted confirmation/picker**: cancelling either leaves the cluster unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The capability MUST be centralized as a `mise` task named `destroy:one` that
  accepts the target environment and an optional release argument, mirroring the existing
  `install`/`destroy` tasks. Direct script invocation MAY remain possible, but `mise run` is the
  documented entry point.
- **FR-002**: The set of selectable releases MUST be the intersection of the releases the
  Helmfile defines for the environment (the source of truth, e.g. `helmfile list`) and the
  releases actually deployed in the cluster (`helm list -A`).
- **FR-003**: A release that exists in the cluster but is **not** defined in the Helmfile MUST
  NOT be selectable or deletable through this task, under any flag combination.
- **FR-004**: When no release argument is given, the task MUST present a `gum` picker containing
  exactly the selectable releases.
- **FR-005**: Deletion MUST remove only the single selected release (via the Helmfile label
  selector mechanism, `-l name=<release> destroy --skip-deps`) and MUST NOT run any
  environment-wide cleanup (Longhorn finalizers, namespace finalizers, CRD removal, Terraform
  destroy).
- **FR-006**: Deletion MUST require explicit confirmation by default (`gum confirm` defaulting to
  "no"), and production deletions MUST require deliberate confirmation per the project's prod
  safety principle.
- **FR-007**: A `--dry-run` mode MUST show the target release's name, namespace, chart, and
  version and exit without changing the cluster.
- **FR-008**: When other releases declare a `needs:` dependency on the target, the task MUST warn
  and list those dependents before deletion proceeds.
- **FR-009**: A `--yes` non-interactive mode MUST skip the interactive prompt while still
  enforcing the prod-safety guard and the YAML/cluster selectability guard; it MUST require an
  explicit release name (it MUST NOT auto-pick).
- **FR-010**: The selection/guard logic MUST live in a reusable `scripts/lib/` helper shared with
  the sibling install-one feature (#29), and the implementation MUST reuse the existing shared
  helpers (`scripts/lib/env.sh`, `scripts/lib/colors.sh`) and `gum`, per the Bash+gum scripting
  principle.
- **FR-011**: Acceptance criteria MUST be authored as `pytest-bdd` Gherkin scenarios under
  `tests/features/`, each tagged exactly one of `@offline` (wiring + guard verified via file
  inspection and by running the script under stubbed `helmfile`/`helm`/`gum`/`kubectl`) or
  `@online` (real deletion against a cluster).
- **FR-012**: The feature MUST be recorded as an ADR under `docs/decisions/<category>/` with an
  `INDEX.md` row, per the project conventions.

### Key Entities

- **Helmfile release**: a single deployable unit defined in `helmfile/releases/*` with a name,
  namespace, chart, version, labels, and optional `needs:` dependencies. The Helmfile definition
  is the source of truth for what may be managed.
- **Cluster release**: a Helm release actually installed in the cluster (`helm list -A`),
  identified by name + namespace. Used only to confirm a defined release is present; never as the
  source of the selectable set.
- **Selectable release**: a release that is both defined in the Helmfile for the environment and
  present in the cluster — the only releases this task may act on.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can delete one managed release by name with a single `mise run`
  command and one confirmation, leaving every other release running.
- **SC-002**: 100% of cluster releases that are not defined in the Helmfile are non-selectable
  and non-deletable through this task, across interactive, by-name, and `--yes` paths.
- **SC-003**: `--dry-run` produces the release preview and makes zero changes to the cluster in
  100% of runs.
- **SC-004**: The offline acceptance scenarios for this feature pass with no cluster access
  (`mise run verify:offline`).
- **SC-005**: A production deletion never proceeds without an explicit, deliberate confirmation.
- **SC-006**: After deleting one release, environment-wide resources owned by other releases
  (their PersistentVolumes, namespaces, CRDs, and Terraform-managed infrastructure) remain
  untouched.

## Assumptions

- The active kube context follows the existing `homelab-<env>` convention and is selected via
  `scripts/lib/env.sh` (argument, `ENV` var, or interactive prompt), as in `install`/`destroy`.
- `helmfile`, `helm`, `gum`, `jq`, and `yq` are available via the pinned `mise` toolchain; the
  task does not assume globally installed tools.
- The Helmfile auto-injects a `name` label per release so the `-l name=<release>` selector
  resolves a single release for deletion. Disambiguating a bare name that maps to multiple
  releases across namespaces is handled by asking the operator to qualify it; hardening that
  selector match is tracked as deferred scope.
- "Already absent" handling and stronger prod type-to-confirm are deferred refinements (issue #30
  deferred list) and are out of scope for this spec's MVP, though the edge case behavior for an
  undeployed release (report and exit cleanly) is specified.
- The sibling install-one feature (#29) will consume the same shared selection helper; this spec
  only requires that the helper be shareable, not that #29 be implemented here.
