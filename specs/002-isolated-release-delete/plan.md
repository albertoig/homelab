# Implementation Plan: Isolated delete of a single Helmfile release

**Branch**: `feat/30-isolated-helmfile-delete-script` | **Date**: 2026-06-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-isolated-release-delete/spec.md`

## Summary

Add a `mise run destroy:one <env> [release]` task that uninstalls exactly one Helmfile-managed
release, selected by name or via a `gum` picker. The set of deletable releases is the
intersection of what the Helmfile defines for the environment (source of truth) and what is
deployed in the cluster; anything running but undefined is never selectable. Deletion uses the
Helmfile label selector (`-l name=<release> destroy --skip-deps`) and deliberately skips all
environment-wide cleanup. The selection/guard logic is extracted into a reusable
`scripts/lib/helmfile.sh` so the sibling install-one feature (#29) shares it. Adds `--dry-run`
(preview), a `needs:`-dependency warning, and a non-interactive `--yes` mode that still enforces
the prod and YAML/cluster guards. Behavior is locked down with pytest-bdd `@offline`/`@online`
scenarios, per the constitution.

## Technical Context

**Language/Version**: Bash (POSIX-friendly), orchestrated by `mise`; tests in Python 3.12
`pytest-bdd` ^7.3.

**Primary Dependencies**: `helmfile` 1.4.1, `helm` 4.2.0, `gum` 0.17.0, `jq` 1.8.1, `yq` 4.47.1,
`kubectl` 1.33.0 — all pinned in `.mise.toml`.

**Storage**: N/A (operates on cluster Helm releases; no local persistence).

**Testing**: pytest-bdd under `tests/features/` tagged `@offline` (wiring + guard via file
inspection and the real script run as a subprocess under stub `helmfile`/`helm`/`gum`/`kubectl`
binaries) and `@online` (real deletion against a `homelab-<env>` cluster).

**Target Platform**: Linux operator workstation with a reachable `homelab-<env>` kube context.

**Project Type**: CLI / operational automation (single repo, Bash scripts wired to mise tasks).

**Performance Goals**: Interactive tool; a single-release delete completes in the time helmfile
takes to uninstall one release. No throughput target.

**Constraints**: Must never delete a release not defined in the Helmfile; must not run env-wide
cleanup; offline tests must pass with no cluster; prod path must be loud and deliberate.

**Scale/Scope**: Two environments (dev/prod), ~tens of releases across the five staged Helmfile
groups. One new lib file, one new script, one mise task, one ADR, plus tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance |
|-----------|------------|
| I. Helmfile is the source of truth | **PASS** — the selectable set is derived from `helmfile list`; the cluster is only cross-checked, never the source. Undefined cluster releases are unreachable by design (FR-002/FR-003). |
| II. Bash + gum, reuse `scripts/lib/` | **PASS** — new `scripts/helm/destroy-one.sh` wired to a mise task; reuses `lib/env.sh`, `lib/colors.sh`, `lib/header.sh`, `gum`; new shared `lib/helmfile.sh` holds the guard (FR-010). No logic inlined in CI/docs. |
| III. Test-first, BDD as the contract | **PASS** — pytest-bdd `.feature` carries `@offline`/`@online` tags; the `@offline` scenarios run the real script under stub tools, and acceptance scenarios map 1:1 to spec scenarios (FR-011). |
| IV. dev/prod + prod safety | **PASS** — env via `lib/env.sh`; default-deny confirm; prod requires deliberate confirmation; `--yes` only for intentional automation (FR-006/FR-009). |
| V. Secrets never in git | **PASS** — offline tests use tool stubs; no secrets read or written; `helmfile list` runs without decrypting runtime secrets for the offline path (see research). |
| Toolchain via mise | **PASS** — all tools already pinned; no new global deps. |
| ADR required | **PLANNED** — ADR under `docs/decisions/<category>/` with an `INDEX.md` row (FR-012). |
| Conventional Commits / release rules | **PASS** — work ships under `feat(scripts)` / `test(...)` scopes, which are intentionally **release-silent** (no version bump for tooling). |

No violations — Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-isolated-release-delete/
├── plan.md              # This file
├── spec.md              # Feature spec (/speckit-specify)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── destroy-one-cli.md   # CLI/task contract
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
scripts/
├── lib/
│   └── helmfile.sh          # NEW — shared selection/guard helpers (reused by #29)
└── helm/
    ├── destroy.sh           # existing env-wide teardown (unchanged)
    └── destroy-one.sh       # NEW — single-release delete entry point

.mise.toml                   # NEW [tasks."destroy:one"] block (mirrors destroy/install)

tests/
└── features/
    ├── isolated_release_delete.feature   # NEW — @offline wiring/guard + @online deletion
    └── test_isolated_release_delete.py   # NEW — pytest-bdd step definitions

docs/decisions/<category>/             # NEW ADR + INDEX.md row
```

**Structure Decision**: Single-repo operational-automation layout. The new code is one shared
library (`scripts/lib/helmfile.sh`), one entry script (`scripts/helm/destroy-one.sh`), and one
mise task, mirroring the existing `destroy`/`install` pattern. Acceptance tests live under
`tests/features/` (pytest-bdd), matching the existing `spec_kit_adoption` precedent.

## Complexity Tracking

> No constitution violations — section intentionally empty.
