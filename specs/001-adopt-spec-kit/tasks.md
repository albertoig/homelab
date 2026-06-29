# Tasks: Adopt Spec Kit + BDD verification loop

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

Tasks are ordered; `[P]` marks work that can proceed in parallel with its siblings.

## Phase 1 — Scaffolding (FR-001, FR-002)

- [x] T001 Pin `uv` and a `spec:init` task in `.mise.toml`; run `specify init --here
  --integration claude` and commit `.specify/`, `specs/`, `.claude/skills/speckit-*`.
- [x] T002 Add `.claude/settings.local.json` to `.gitignore` (commit skills, not local
  settings).
- [x] T003 Fill `.specify/memory/constitution.md` with project conventions, including the
  Angular semantic-release bump rules and the BDD offline/online model.

## Phase 2 — BDD verification layer (FR-003, FR-004)

- [x] T004 Add `pytest-bdd` to `pyproject.toml`; set `bdd_features_base_dir` and register
  the `offline`/`online` markers.
- [x] T005 Author `tests/features/spec_kit_adoption.feature` (`@offline` scenarios).
- [x] T006 Implement step defs in `tests/features/test_spec_kit_adoption.py`.
- [x] T007 Add `.mise.toml` tasks `verify` (offline+online) and `verify:offline` (offline).

## Phase 3 — Enforcement (FR-005, FR-006a)

- [x] T008 Add the `offline-bdd` pre-commit hook running `mise run verify:offline`.
- [x] T009 Add the `offline-bdd` job to `.github/workflows/validate.yml` (no change gate;
  reaches `main`/`beta` via `release.yml`'s `workflow_call`).

## Phase 4 — Docs + ADR (FR-006, FR-007)

- [ ] T010 [P] Add the SDD workflow + spec threshold to `CONTRIBUTING.md`.
- [ ] T011 [P] Add the pytest-bdd / offline-online section to `docs/TESTING.md`.
- [ ] T012 [P] Add a Spec-Driven Development pointer to `README.md`.
- [ ] T013 Add `docs/decisions/project/ADR-NNN-adopt-spec-kit.md` and an `INDEX.md` row.

## Phase 5 — Verify (SC-001…SC-003a)

- [ ] T014 `mise run setup` (or `poetry install`) then `mise run verify:offline` passes
  locally; confirm the pre-commit hook and the CI job invoke the same command.
