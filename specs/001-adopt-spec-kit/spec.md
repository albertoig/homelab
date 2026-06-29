# Feature Specification: Adopt Spec Kit + BDD verification loop

**Feature Branch**: `feat/issue-31-spec-kit`

**Created**: 2026-06-29

**Status**: Draft

**Input**: GitHub issue #31 — "Adopt Spec Kit (Spec-Driven Development) in the project",
plus the requirement that BDD be the verification loop so that every code change can be
verified, split into an offline subset (runs everywhere, including CI on every branch) and
an online subset (runs locally against a cluster).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start work from a written spec (Priority: P1)

As a maintainer, when I begin meaningful work (a new script, chart, service, or infra
change) I capture **what** and **why** in a spec before **how**, using the Spec Kit flow
(`/speckit-specify → /speckit-plan → /speckit-tasks → /speckit-implement`) from my AI agent
of choice (Spec Kit is agent-agnostic), backed by a project constitution that encodes our
conventions.

**Why this priority**: This is the core of issue #31 — without the scaffolding and
constitution there is no spec-driven flow.

**Independent Test**: With only this story done, a contributor can run the `/speckit-*`
commands from their AI agent and produce a spec under `specs/`, and the constitution exists
and is filled in.

**Acceptance Scenarios**:

1. **Given** the repo, **When** I inspect it, **Then** `.specify/`, `specs/`, and the
   committed agent integration (`.claude/skills/speckit-*`) exist and the constitution is
   filled in (no template placeholders).

### User Story 2 - Verify every change with BDD, offline in CI (Priority: P1)

As a maintainer, I express acceptance criteria as Gherkin scenarios tagged `@offline` or
`@online`. `mise run verify` runs both locally; `mise run verify:offline` runs only the
offline subset and is exactly what the CI pipeline runs on every branch — including `beta`
and `main`.

**Why this priority**: This is the "verify everything works on every change" requirement.
The offline/online split keeps CI cluster-free while still gating every branch.

**Independent Test**: `mise run verify:offline` passes with no cluster; the CI pipeline
runs that same command on `main`, `beta`, and feature branches; no CI job runs `@online`
scenarios.

**Acceptance Scenarios**:

1. **Given** no cluster, **When** I run `mise run verify:offline`, **Then** the offline
   scenarios pass.
2. **Given** a push to `main`, `beta`, or a feature branch, **When** CI runs, **Then** the
   offline acceptance scenarios are executed (`mise run verify:offline`).
3. **Given** the CI configuration, **When** inspected, **Then** no workflow runs `@online`
   scenarios.
4. **Given** a commit that touches specs, features, or the verify wiring, **When** the
   pre-commit hooks run, **Then** the `offline-bdd` hook runs `mise run verify:offline`
   and blocks the commit on failure.

### Edge Cases

- A spec with no `@online` scenarios: `mise run verify` still succeeds (runs the offline
  ones).
- Pushes to `main`/`beta` are validated via `release.yml`'s `workflow_call` into
  `validate.yml`, so the offline gate runs there without a duplicate direct run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repo MUST contain Spec Kit scaffolding (`.specify/`, `specs/`) and a
  committed AI-agent integration (Claude Code, under `.claude/skills/`) enabling the
  `/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement` commands.
  Spec Kit is agent-agnostic; other agents may be added via `specify init`.
- **FR-002**: A project constitution MUST capture the project's conventions (helmfile as
  source of truth, bash+gum scripts and `scripts/lib` reuse, dev/prod + prod safety,
  secrets handling, ADRs, Conventional Commits with the Angular release-bump rules, the
  BDD offline/online model, and the spec threshold).
- **FR-003**: Acceptance criteria MUST be authored as `pytest-bdd` Gherkin scenarios under
  `tests/features/`, each tagged exactly one of `@offline` or `@online`.
- **FR-004**: `mise run verify` MUST run both `@offline` and `@online` scenarios;
  `mise run verify:offline` MUST run only `@offline`.
- **FR-005**: The CI pipeline (`validate.yml`, reached on `main`/`beta` via `release.yml`)
  MUST run `mise run verify:offline` on every branch and MUST NOT run `@online` scenarios.
- **FR-006a**: A pre-commit hook MUST enforce the offline gate locally by running
  `mise run verify:offline` when specs, feature files, or the verify wiring change, so
  failing offline scenarios block the commit.
- **FR-006**: The workflow MUST be documented in `CONTRIBUTING.md`/`docs/TESTING.md`,
  including the threshold for when a spec is expected vs. a quick fix.
- **FR-007**: Adoption MUST be recorded as an ADR under `docs/decisions/project/`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `mise run verify:offline` passes locally with no cluster access.
- **SC-002**: The offline acceptance scenarios (`tests/features/spec_kit_adoption.feature`)
  pass and assert the scaffolding, constitution, mise wiring, and CI enforcement.
- **SC-003**: CI runs the offline gate on `main`, `beta`, and feature branches; zero CI
  jobs execute `@online` scenarios.
- **SC-003a**: The pre-commit `offline-bdd` hook runs `mise run verify:offline` and blocks
  commits when offline scenarios fail.
- **SC-004**: A new contributor can produce a spec via the `/speckit-*` flow without extra
  tooling beyond `mise run setup`.

## Assumptions

- The `specify` CLI is run via `uvx` (uv is already available); the generated `.specify/`
  and `.claude/skills/speckit-*` artifacts are committed so day-to-day use needs no network.
- `.claude/settings.local.json` stays local (gitignored) while the `speckit-*` skills are
  committed.
- The legacy pytest suites under `tests/smoke/` and `tests/k8s/` are out of scope here and
  may later be migrated into `@online` scenarios.
