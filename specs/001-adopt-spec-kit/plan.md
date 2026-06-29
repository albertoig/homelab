# Implementation Plan: Adopt Spec Kit + BDD verification loop

**Spec**: [spec.md](./spec.md) · **Branch**: `feat/issue-31-spec-kit`

## Constitution check

This work *establishes* the constitution, so it must itself comply with it: BDD as the
contract (the acceptance scenarios in `tests/features/spec_kit_adoption.feature`),
offline/online split, Conventional Commits (`docs(docs)` / `ci` / `test` scopes — no
release bump), and an ADR under `docs/decisions/project/`.

## Technical approach

1. **Scaffold Spec Kit** via `uvx --from git+https://github.com/github/spec-kit.git
   specify init --here --integration claude --script sh`. Commit `.specify/`, `specs/`,
   and `.claude/skills/speckit-*`. Keep `.claude/settings.local.json` gitignored.
2. **Constitution** — fill `.specify/memory/constitution.md` with the project's real
   conventions, including the Angular semantic-release bump rules (source of truth:
   `package.json` → `release` + `docs/VERSIONING.md`).
3. **BDD layer (pytest-bdd)** — add `pytest-bdd` to `pyproject.toml`; configure
   `bdd_features_base_dir = "tests/features"` and register the `offline`/`online` markers;
   author scenarios + step defs under `tests/features/`.
4. **Verify wiring (mise)** — `verify` runs `-m 'offline or online'`; `verify:offline`
   runs `-m offline`.
5. **Enforce in three places** — pre-commit `offline-bdd` hook, the `offline-bdd` job in
   `validate.yml` (no change gate; reaches `main`/`beta` via `release.yml`), and local
   `mise run verify`.
6. **Docs + ADR** — `CONTRIBUTING.md` SDD section + threshold, `docs/TESTING.md`
   pytest-bdd section, README pointer, and `docs/decisions/project/ADR-NNN-adopt-spec-kit.md`
   with an INDEX row.

## Key files

- `.specify/memory/constitution.md`, `.specify/`, `.claude/skills/speckit-*`
- `pyproject.toml`, `.mise.toml`
- `tests/features/spec_kit_adoption.feature`, `tests/features/test_spec_kit_adoption.py`
- `.pre-commit-config.yaml`, `.github/workflows/validate.yml`
- `CONTRIBUTING.md`, `docs/TESTING.md`, `README.md`, `docs/decisions/`

## Risks / decisions

- `specify init` writes into `.claude/`; verify `settings.local.json` survives and add it
  to `.gitignore` so skills are committed but local settings are not.
- Avoid double CI runs on `main`/`beta`: keep `validate.yml` `branches-ignore: [main, beta]`
  and rely on `release.yml`'s `workflow_call`; the `offline-bdd` job has no `if` so it runs
  under that call.
