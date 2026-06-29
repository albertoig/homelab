# ADR-002: Adopt Spec Kit (Spec-Driven Development) with a BDD verification loop

- **Date**: 2026-06-29
- **Status**: Proposed
- **Deciders**: Alberto Iglesias
- **Category**: project

## Context

The project has grown (staged helmfile releases, isolated install/delete scripts, SSO,
secrets management). Work has tended to start from ad-hoc implementation, and there was no
single executable definition of "the project still works" to gate changes. Issue #31 asked
to adopt [Spec Kit](https://github.com/github/spec-kit) so new work starts from a written
spec/plan, and the maintainer additionally wanted Behaviour-Driven tests to be the
verification loop on every change — split so the cluster-free subset can run everywhere
(pre-commit and CI on every branch) while cluster-facing checks run locally.

The repo already had the right substrate: `mise` task orchestration, shellspec BDD for
shell scripts, pytest integration tests, pre-commit hooks, and a `validate.yml` CI workflow
reused by `release.yml` via `workflow_call`.

## Decision

Adopt Spec Kit and a pytest-bdd acceptance layer:

- Scaffold Spec Kit (`.specify/`, `specs/`) via the `specify` CLI (run with `uvx`; `uv`
  pinned in `.mise.toml`). Commit the scaffolding and the AI-agent integration. Spec Kit is
  **agent-agnostic**; this repo ships the Claude Code integration under `.claude/skills/`,
  and other agents can be added with `specify init`.
- Write a project [constitution](../../../.specify/memory/constitution.md) capturing the
  real conventions (helmfile as source of truth, bash+gum + `scripts/lib` reuse, dev/prod
  and prod safety, secrets handling, ADRs, Conventional Commits with the Angular
  release-bump rules, and the BDD model).
- Author acceptance criteria as Gherkin scenarios under `tests/features/` (pytest-bdd),
  each tagged exactly one of `@offline` (no cluster) or `@online` (needs a cluster).
- Provide two entry points: `mise run verify` (both tags) and `mise run verify:offline`
  (offline only). Enforce the offline gate in pre-commit (`offline-bdd` hook) and CI (the
  `offline-bdd` job in `validate.yml`, no change gate, reaching `main`/`beta` via
  `release.yml`).

## Alternatives Considered

### Option A: Spec Kit + pytest-bdd (chosen)

- **Description**: SDD scaffolding plus a Gherkin acceptance layer wired into mise/CI/pre-commit.
- **Pros**:
  - Specs and their executable acceptance criteria live with the code and run on every change.
  - Offline/online split keeps CI cluster-free while still gating every branch.
  - Reuses existing `mise`, pytest fixtures, pre-commit, and `validate.yml` patterns.
- **Cons**:
  - Adds the `pytest-bdd` dependency and a second test style alongside shellspec.
  - Spec Kit scaffolding is extra surface area to maintain.

### Option B: Constitution + docs only, no tooling

- **Description**: Document the workflow and conventions without the `specify` CLI or BDD layer.
- **Pros**:
  - Zero new dependencies.
- **Cons**:
  - No executable acceptance criteria; "verify everything works" stays manual.
  - Loses the structured `/speckit-*` flow and reviewable per-feature specs.

## Consequences

### Positive

- Every change is gated by an offline BDD suite in pre-commit and CI on all branches.
- New work has a consistent spec → plan → tasks → implement flow and a constitution to
  comply with.

### Negative

- Contributors learn pytest-bdd in addition to shellspec.
- The legacy `tests/smoke/` and `tests/k8s/` suites now overlap conceptually with `@online`
  scenarios and will need migration.

### Risks

- `specify init` writes into `.claude/`; mitigated by keeping `.claude/settings.local.json`
  gitignored while committing the skills.
- Online scenarios can only run where a cluster is reachable; mitigated by the explicit
  `@offline`/`@online` split so CI never depends on a cluster.

## References

- [Issue #31 — Adopt Spec Kit](https://github.com/albertoig/homelab/issues/31)
- [Spec Kit](https://github.com/github/spec-kit)
- [Project constitution](../../../.specify/memory/constitution.md)
- [specs/001-adopt-spec-kit/spec.md](../../../specs/001-adopt-spec-kit/spec.md)
