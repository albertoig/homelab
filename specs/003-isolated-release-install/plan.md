# Implementation Plan: Isolated install/update of a single Helmfile release

**Branch**: `feat/29-isolated-helmfile-install-script` | **Date**: 2026-07-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-isolated-release-install/spec.md`

## Summary

Add a `mise run install:one <env> [release]` task that installs or updates exactly one
Helmfile-managed release, selected by name or via a `gum` picker. The set of selectable releases is
everything the Helmfile **defines** for the environment (source of truth); the cluster is
cross-checked only to label each target `install` (not deployed) or `update` (deployed). Anything
running but undefined is never selectable. The sync uses the Helmfile label selector
(`-l name=<release> sync --skip-deps`) and deliberately skips the full-environment sync and
Terraform/Velero steps. The selection/guard logic reuses the shared `scripts/lib/helmfile.sh`
introduced by #30, extended with an install-set helper. Adds `--dry-run` (preview), a `needs:`
prerequisite warning, a non-interactive `--yes` mode that still enforces the prod and YAML/cluster
guards, and `gum` spinners on every blocking step. Behavior is locked down with pytest-bdd
`@offline`/`@online` scenarios, per the constitution.

## Technical Context

**Language/Version**: Bash (POSIX-friendly), orchestrated by `mise`; tests in Python 3.12
`pytest-bdd` ^7.3.

**Primary Dependencies**: `helmfile`, `helm`, `gum` 0.17.0, `jq`, `yq`, `kubectl` — all pinned in
`.mise.toml`.

**Storage**: N/A (operates on cluster Helm releases; no local persistence).

**Testing**: pytest-bdd under `tests/features/` tagged `@offline` (wiring + guard via file
inspection and the real script run as a subprocess under stub `helmfile`/`helm`/`gum`/`kubectl`
binaries) and `@online` (real sync against a `homelab-<env>` cluster).

**Target Platform**: Linux operator workstation with a reachable `homelab-<env>` kube context.

**Project Type**: CLI / operational automation (single repo, Bash scripts wired to mise tasks).

**Performance Goals**: Interactive tool; a single-release sync completes in the time helmfile takes
to sync one release. No throughput target.

**Constraints**: Must never sync a release not defined in the Helmfile; must not run a
full-environment sync; offline tests must pass with no cluster; prod path must be loud and
deliberate; no silent freezes (spinners on waits).

**Scale/Scope**: Two environments (dev/prod), ~tens of releases. One extended lib helper, one new
script, one mise task, plus tests and docs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance |
|-----------|------------|
| I. Helmfile is the source of truth | **PASS** — the selectable set is derived from `helmfile list`; the cluster is only cross-checked (install/update label), never the source. Undefined cluster releases are unreachable by design (FR-002/FR-003/FR-004). |
| II. Bash + gum, reuse `scripts/lib/` | **PASS** — new `scripts/helm/install-one.sh` wired to a mise task; reuses `lib/env.sh`, `lib/colors.sh`, `lib/header.sh`, `gum`; reuses/extends the shared `lib/helmfile.sh` guard (FR-011). |
| III. Test-first, BDD as the contract | **PASS** — pytest-bdd `.feature` carries `@offline`/`@online` tags; `@offline` scenarios run the real script under stub tools; acceptance scenarios map 1:1 to spec scenarios (FR-012). Spec + BDD authored before implementation. |
| IV. dev/prod + prod safety | **PASS** — env via `lib/env.sh`; confirm before sync; prod requires deliberate confirmation; `--yes` only for intentional automation (FR-007/FR-010). |
| V. Secrets never in git | **PASS** — offline tests use tool stubs; no secrets read or written. |
| Toolchain via mise | **PASS** — all tools already pinned; no new global deps. |
| ADR required | **N/A / reuse** — the isolated single-release design + YAML-as-source-of-truth guard are already recorded for #30; this feature is the sibling install path on the same design. A short note/row may be added if the ADR index warrants it. |
| Conventional Commits / release rules | **PASS** — ships under `feat(scripts)` / `test(...)` / `docs(...)` scopes, which are intentionally release-silent (no version bump for tooling). |

No violations — Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-isolated-release-install/
├── plan.md              # This file
├── spec.md              # Feature spec
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── install-one-cli.md   # CLI/task contract
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
scripts/
├── lib/
│   └── helmfile.sh          # EXTEND — add install-set helpers (installable rows, cluster keys, requirements)
└── helm/
    ├── install.sh           # existing env-wide sync (unchanged)
    ├── destroy-one.sh       # sibling single-release delete (unchanged)
    └── install-one.sh       # NEW — single-release install/update entry point

.mise.toml                   # NEW [tasks."install:one"] block (mirrors destroy:one)

tests/
└── features/
    ├── isolated_release_install.feature   # NEW — @offline wiring/guard + @online sync
    └── test_isolated_release_install.py   # NEW — pytest-bdd step definitions

docs/SCRIPTS.md              # UPDATE — document mise run install:one + install-one.sh
```

**Structure Decision**: Single-repo operational-automation layout. The new code is one new entry
script (`scripts/helm/install-one.sh`), extensions to the shared `scripts/lib/helmfile.sh`, and one
mise task, mirroring the `destroy:one` pattern. Acceptance tests live under `tests/features/`
(pytest-bdd), matching the `isolated_release_delete` precedent.

## Complexity Tracking

> No constitution violations — section intentionally empty.
