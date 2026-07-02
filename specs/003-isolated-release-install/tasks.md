---
description: "Task list for isolated single-release install/update (issue #29)"
---

# Tasks: Isolated install/update of a single Helmfile release

**Input**: Design documents from `specs/003-isolated-release-install/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/install-one-cli.md, quickstart.md

**Tests**: INCLUDED — the constitution makes BDD the contract (Principle III) and the spec requires
pytest-bdd acceptance scenarios (FR-012). Tests are authored per story, before that story's
implementation.

**Organization**: Tasks are grouped by user story (from spec.md) so each story is an independently
testable increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: US1–US5 from spec.md

> **Same-file note**: All Gherkin scenarios live in one feature file and all step definitions in one
> step module; all shell behavior lives in one entry script. Tasks touching those shared files are
> therefore **not** marked `[P]` relative to each other, even across stories.

## Path Conventions

Single-repo operational automation (see plan.md → Project Structure):
`scripts/lib/`, `scripts/helm/`, `.mise.toml`, `tests/features/`, `docs/`.

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 [P] Add `[tasks."install:one"]` to `.mise.toml`: `usage` block with optional
  `[environment]`, optional `[release]`, and `--dry-run` / `--yes` flags; `run` passes the parsed
  `usage_*` values through to `./scripts/helm/install-one.sh` (mirror `destroy:one`).
- [ ] T002 [P] Create `scripts/helm/install-one.sh` skeleton: shebang, `set -e`, source
  `lib/colors.sh`, `lib/header.sh`, `lib/env.sh`, `lib/helmfile.sh`; tool presence check; parse
  `[env] [release] --dry-run --yes` (and `MISE_NONINTERACTIVE`→`--yes`) into variables; `chmod +x`.
- [ ] T003 [P] Create `tests/features/isolated_release_install.feature`: Feature header and the
  `@offline`/`@online` scenario blocks (one per user story).
- [ ] T004 Create `tests/features/test_isolated_release_install.py`:
  `scenarios("isolated_release_install.feature")` binding, `repo_root` fixture, and a reusable
  **stub-PATH fixture** that writes stub `helmfile`/`helm`/`gum`/`kubectl` onto a temp `PATH`,
  drives canned `list --output json`, records the `sync` argv and the `gum spin` titles to files
  (see contracts/install-one-cli.md → Stub contract). *(depends on T003)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: Provides the install-set guard reused by every story.

- [ ] T005 [P] Extend `scripts/lib/helmfile.sh`: add `helmfile_cluster_keys`,
  `helmfile_installable_rows` (every defined release keyed `namespace/name`, tagged `install`/
  `update` from the cluster cross-check) and `helmfile_requirements` (a release's own `needs:`),
  and document them in the header's Public API. Reuse the existing `_hf_jq_key` and helpers.
- [ ] T006 In `scripts/helm/install-one.sh`, resolve env via `lib/env.sh`, load the install set via
  `helmfile_installable_rows` behind a spinner, and handle shared edge cases: cluster-unreachable →
  clear error exit 1; no defined releases → message and exit 0. *(depends on T002, T005)*

**Checkpoint**: Guard + install-set plumbing ready — user stories can begin.

---

## Phase 3: User Story 1 - Safely install/update one managed release by name (P1) 🎯 MVP

**Goal**: `mise run install:one <env> <release>` syncs exactly one defined release, install or
update; unmanaged targets are refused; no full-environment sync runs.

- [ ] T007 [US1] Add US1 `@offline` scenarios + step defs: by-name sync invokes
  `-l name=<release> sync --skip-deps`; defined-not-deployed → labelled `install`;
  defined-and-deployed → labelled `update`; unmanaged cluster release refused (exit 1); only one
  release synced (no full-env sync). *(depends on T004, T006)*
- [ ] T008 [US1] Add the US1 `@online` scenario + steps: against a `homelab-<env>` cluster, syncing
  a throwaway release leaves sibling releases untouched. *(depends on T007)*
- [ ] T009 [US1] Implement selection + guard in `scripts/helm/install-one.sh`: match the `release`
  arg (bare `name` or `namespace/name`) against the install set; refuse unmanaged (running but not
  defined) and unknown names; on a bare name matching multiple releases, ask to qualify. *(depends on T006)*
- [ ] T010 [US1] Implement single-release sync via
  `helmfile -f helmfile.yaml.gotmpl -e <env> -l name=<release> sync --skip-deps` behind a spinner;
  ensure no full-environment sync / Terraform / Velero steps run. *(depends on T009)*
- [ ] T011 [US1] Add the `gum confirm` gate and explicit prod-safety messaging before the sync. *(depends on T010)*

**Checkpoint**: MVP — safe by-name install/update with the guard is functional and testable.

---

## Phase 4: User Story 2 - Pick a release interactively (P2)

- [ ] T012 [US2] Add US2 `@offline` scenarios + steps: no-release run offers a picker containing
  exactly the selectable releases (each tagged install/update); unmanaged release not offered;
  cancelling performs no sync; loading + syncing spinners are shown. *(depends on T004, T009)*
- [ ] T013 [US2] Implement the `gum choose` picker in `scripts/helm/install-one.sh` when `release`
  is omitted, with the `/dev/tty` handling used by `lib/env.sh`; annotate each row with the action
  and feed the chosen key into the selection flow. *(depends on T009)*

---

## Phase 5: User Story 3 - Preview & prerequisite awareness (P2)

- [ ] T014 [US3] Add US3 `@offline` scenarios + steps: `--dry-run` prints
  release/namespace/chart/version/action and records no sync; a target with a `needs:` lists that
  prerequisite as a warning. *(depends on T004, T009)*
- [ ] T015 [US3] Implement the `--dry-run` preview using `helmfile_release_meta` + the action label,
  exiting 0 before any sync. *(depends on T009)*
- [ ] T016 [US3] Implement the prerequisite warning using `helmfile_requirements`, shown before the
  confirmation prompt. *(depends on T009)*

---

## Phase 6: User Story 4 - Non-interactive install/update for automation (P2)

- [ ] T017 [US4] Add US4 `@offline` scenarios + steps: `--yes` non-prod selectable syncs with no
  prompt; `--yes` without a release → exit 1; `--yes` unmanaged → refused; prod under `--yes` still
  requires confirmation. *(depends on T004, T011)*
- [ ] T018 [US4] Implement the `--yes` path in `scripts/helm/install-one.sh`: bypass the interactive
  confirm but enforce release-required, the selectability guard, and prod safety. *(depends on T011)*

---

## Phase 7: User Story 5 - Shared selection library reused from destroy-one (P3)

- [ ] T019 [US5] Add the US5 `@offline` scenario + steps: assert `scripts/lib/helmfile.sh` provides
  `helmfile_installable_rows`, `scripts/helm/install-one.sh` sources the lib and uses it, and the
  guard is not duplicated inline (no `--argjson` in the entry script). *(depends on T004, T005)*
- [ ] T020 [US5] Finalize the shared helper API docs in the `scripts/lib/helmfile.sh` header
  (delete-set vs install-set notions). *(depends on T005)*

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T021 [P] Document `mise run install:one` (env/release/--dry-run/--yes) in `docs/SCRIPTS.md`
  next to `destroy:one`.
- [ ] T022 Run `mise run verify:offline` and `mise run lint`; ensure all `@offline` scenarios pass
  and shell/TOML lint cleanly; fix findings.
- [ ] T023 Run the `quickstart.md` online validation against a `dev` cluster (`mise run verify`).

---

## Dependencies & Execution Order

- **Setup (Phase 1)**: T001/T002/T003 parallel; T004 follows T003.
- **Foundational (Phase 2)**: T005 parallel with Setup; T006 needs T002+T005. **Blocks all stories.**
- **User stories (Phases 3–7)**: all start after T006. US1 is the MVP; US2/US3/US4 depend on the US1
  selection core; US5 depends only on the lib.
- **Polish (Phase 8)**: after the desired stories are complete.

### Critical path

T002/T003 → T004/T005 → T006 → T007 → T009 → T010 → T011 → (T013 / T015 / T016 / T018) → T022.

### Same-file serialization

- `scripts/helm/install-one.sh` is edited by T002, T006, T009, T010, T011, T013, T015, T016, T018 →
  sequential.
- `isolated_release_install.feature` and `test_isolated_release_install.py` are edited by T003/T004
  and every `[US*]` test task → sequential.

---

## Notes

- Test-first: within each story, author the scenario + steps before the implementation task.
- Ship under `feat(scripts)` / `test(...)` / `docs(...)` scopes (release-silent per the constitution).
- Deferred (out of scope, shared with #30): hardened multi-match selector safety; a `helmfile diff`
  based dry-run preview; stronger prod type-to-confirm.
