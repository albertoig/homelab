---

description: "Task list for isolated single-release delete (issue #30)"
---

# Tasks: Isolated delete of a single Helmfile release

**Input**: Design documents from `specs/002-isolated-release-delete/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/destroy-one-cli.md, quickstart.md

**Tests**: INCLUDED — the constitution makes BDD the contract (Principle III) and the spec
requires pytest-bdd acceptance scenarios (FR-011). Tests are authored per story, before that
story's implementation.

**Organization**: Tasks are grouped by user story (from spec.md) so each story is an independently
testable increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: US1–US5 from spec.md

> **Same-file note**: All Gherkin scenarios live in one feature file and all step definitions in
> one step module; all shell behavior lives in one entry script. Tasks touching those shared files
> are therefore **not** marked `[P]` relative to each other, even across stories.

## Path Conventions

Single-repo operational automation (see plan.md → Project Structure):
`scripts/lib/`, `scripts/helm/`, `.mise.toml`, `tests/features/`, `docs/decisions/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Skeletons and wiring so each story can add behavior + scenarios incrementally.

- [ ] T001 [P] Add `[tasks."destroy:one"]` to `.mise.toml`: `usage` block with optional
  `[environment]`, optional `[release]`, and `--dry-run` / `--yes` flags; `run` passes the parsed
  `usage_*` values through to `./scripts/helm/destroy-one.sh` (mirror the existing `destroy` task).
- [ ] T002 [P] Create `scripts/helm/destroy-one.sh` skeleton: shebang, `set -e`, source
  `lib/colors.sh`, `lib/header.sh`, `lib/env.sh`, `lib/helmfile.sh`; `gum` presence check; parse
  `[env] [release] --dry-run --yes` (and `MISE_NONINTERACTIVE`→`--yes`) into variables; `chmod +x`.
- [ ] T003 [P] Create `tests/features/isolated_release_delete.feature`: Feature header and the
  `@offline`/`@online` scenario placeholders (one block per user story).
- [ ] T004 Create `tests/features/test_isolated_release_delete.py`: `scenarios("isolated_release_delete.feature")`
  binding, `repo_root` fixture, and a reusable **stub-PATH fixture** that writes stub
  `helmfile`/`helm`/`gum`/`kubectl` onto a temp `PATH`, drives canned `list --output json`, and
  records the `destroy` argv to a file (see contracts/destroy-one-cli.md → Stub contract).
  *(depends on T003)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story can be completed until this phase is done — it provides the guard.

- [ ] T005 [P] Implement `scripts/lib/helmfile.sh` shared helpers: `helmfile_defined_releases`
  (`helmfile -e <env> list --output json`), `helmfile_cluster_releases` (`helm list -A --output json`),
  `helmfile_selectable_releases` (jq intersection keyed `namespace/name`, default ns → `default`),
  `helmfile_release_meta` (chart/version), `helmfile_dependents` (`helmfile build` + `yq`). This is
  the YAML∩cluster guard reused by #29.
- [ ] T006 In `scripts/helm/destroy-one.sh`, resolve env via `lib/env.sh`, load the selectable set
  via `lib/helmfile.sh`, and handle the shared edge cases: cluster-unreachable → clear error exit 1;
  no selectable releases → message and exit 0. *(depends on T002, T005)*

**Checkpoint**: Guard + selectable-set plumbing ready — user stories can begin.

---

## Phase 3: User Story 1 - Safely delete one managed release by name (Priority: P1) 🎯 MVP

**Goal**: `mise run destroy:one <env> <release>` deletes exactly one defined-and-deployed release;
unmanaged or undeployed targets are refused/no-op; no env-wide cleanup runs.

**Independent Test**: With a stubbed `helmfile`/`helm`, deleting a managed release records exactly
`-l name=<release> destroy --skip-deps`; an unmanaged cluster release is refused; an undeployed
defined name reports nothing-to-delete; the destroy stub is never called for those.

- [ ] T007 [US1] Add US1 `@offline` scenarios to `tests/features/isolated_release_delete.feature`
  and their step defs to `tests/features/test_isolated_release_delete.py`: by-name delete invokes
  `-l name=<release> destroy --skip-deps`; unmanaged cluster release refused (exit 1); defined-but-
  undeployed → nothing-to-delete (exit 0); env-wide cleanup steps never invoked. *(depends on T004, T006)*
- [ ] T008 [US1] Add the US1 `@online` scenario + steps: against a `homelab-<env>` cluster, deleting
  a throwaway release leaves sibling releases running and removes no env-wide resources. *(depends on T007)*
- [ ] T009 [US1] Implement selection + guard in `scripts/helm/destroy-one.sh`: match the `release`
  arg (bare `name` or `namespace/name`) against the selectable set; refuse unmanaged; report
  undeployed; on a bare name matching multiple releases, ask to qualify with `namespace/name`. *(depends on T006)*
- [ ] T010 [US1] Implement single-release deletion via
  `helmfile -f helmfile.yaml.gotmpl -e <env> -l name=<release> destroy --skip-deps`; ensure NONE of
  the env-wide steps (Longhorn/namespace finalizers, CRD removal, Terraform) run. *(depends on T009)*
- [ ] T011 [US1] Add default-deny `gum confirm` and explicit prod-safety messaging before the
  deletion runs. *(depends on T010)*

**Checkpoint**: MVP — safe by-name deletion with the guard is fully functional and testable.

---

## Phase 4: User Story 2 - Pick a release interactively (Priority: P2)

**Goal**: `mise run destroy:one <env>` (no release) shows a `gum` picker of exactly the selectable
releases; cancelling changes nothing.

**Independent Test**: With no release arg, the picker is offered the selectable set only; selecting
proceeds to the US1 confirm/delete flow; cancelling deletes nothing.

- [ ] T012 [US2] Add US2 `@offline` scenarios + steps (feature + step module): no-release run offers
  a picker containing exactly the selectable releases; cancelling the picker performs no destroy. *(depends on T004, T009)*
- [ ] T013 [US2] Implement the `gum choose` picker in `scripts/helm/destroy-one.sh` when `release`
  is omitted, with the `/dev/tty` handling used by `lib/env.sh`; feed the choice into the selection
  flow from T009. *(depends on T009)*

**Checkpoint**: Interactive selection works on top of the MVP.

---

## Phase 5: User Story 3 - Preview & dependency awareness (Priority: P2)

**Goal**: `--dry-run` previews name/namespace/chart/version with no changes; dependents that
`needs:` the target are listed before deletion.

**Independent Test**: `--dry-run` prints the four fields and the destroy stub is never called; when
another release `needs:` the target, the dependents are listed.

- [ ] T014 [US3] Add US3 `@offline` scenarios + steps (feature + step module): `--dry-run` prints
  release/namespace/chart/version and records no destroy; a target with a `needs:` dependent lists
  that dependent as a warning. *(depends on T004, T009)*
- [ ] T015 [US3] Implement the `--dry-run` preview in `scripts/helm/destroy-one.sh` using
  `helmfile_release_meta`, exiting 0 before any destroy. *(depends on T009)*
- [ ] T016 [US3] Implement the dependents warning using `helmfile_dependents`, shown before the
  confirmation prompt. *(depends on T009)*

**Checkpoint**: Preview + dependency safety layered on without affecting US1/US2.

---

## Phase 6: User Story 4 - Non-interactive deletion for automation (Priority: P2)

**Goal**: `--yes` skips the prompt while still enforcing the guard and prod safety, and requires an
explicit release name.

**Independent Test**: `--yes` + explicit selectable non-prod release deletes without prompting;
`--yes` without a release is refused; `--yes` on an unmanaged release is still refused; prod still
demands explicit confirmation.

- [ ] T017 [US4] Add US4 `@offline` scenarios + steps (feature + step module): `--yes` non-prod
  selectable deletes with no prompt; `--yes` without a release → exit 1; `--yes` unmanaged → refused;
  prod under `--yes` still requires confirmation. *(depends on T004, T011)*
- [ ] T018 [US4] Implement the `--yes` path in `scripts/helm/destroy-one.sh`: bypass the interactive
  confirm but enforce release-required, the selectability guard, and prod safety. *(depends on T011)*

**Checkpoint**: Automation-safe path ready for the future CI pipeline (#28).

---

## Phase 7: User Story 5 - Shared selection library reused by install-one (Priority: P3)

**Goal**: The guard/selection logic lives in `scripts/lib/helmfile.sh` (not inline) so #29 reuses it.

**Independent Test**: Inspection confirms the guard logic resides in the shared lib and the entry
script sources it rather than re-implementing it.

- [ ] T019 [US5] Add the US5 `@offline` scenario + steps (feature + step module): assert
  `scripts/lib/helmfile.sh` exists, `scripts/helm/destroy-one.sh` sources it, and the selectable/
  guard logic is not duplicated inline in the script. *(depends on T004, T005)*
- [ ] T020 [US5] Finalize and document the public helper API in the `scripts/lib/helmfile.sh` header
  (function names, args, output contracts) so install-one (#29) can consume it unchanged. *(depends on T005)*

**Checkpoint**: All stories functional; shared lib documented for #29.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T021 [P] Add an ADR under `docs/decisions/<category>/` recording the isolated single-release
  delete design (YAML-as-source-of-truth guard, label-selector deletion, no env-wide cleanup) and
  add its row to the `INDEX.md`.
- [ ] T022 [P] Document `mise run destroy:one` usage (env/release/--dry-run/--yes) in the relevant
  `README.md`/`CONTRIBUTING.md`/`docs/` location next to the existing `destroy` docs.
- [ ] T023 Run `mise run verify:offline` and `mise run lint`; ensure all `@offline` scenarios pass
  and the new shell/TOML lint cleanly; fix any findings.
- [ ] T024 Run the `quickstart.md` online validation against a `dev` cluster (`mise run verify`).

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies; T001/T002/T003 are parallel, T004 follows T003.
- **Foundational (Phase 2)**: T005 parallel with Setup; T006 needs T002+T005. **Blocks all stories.**
- **User stories (Phases 3–7)**: all start after T006. US1 is the MVP; US2/US3/US4 depend on the
  US1 selection core (T009/T011); US5 depends only on the lib (T005).
- **Polish (Phase 8)**: after the desired stories are complete.

### Critical path

T002/T003 → T004/T005 → T006 → T007 → T009 → T010 → T011 → (T013 / T015 / T016 / T018) → T023.

### Same-file serialization (limits parallelism)

- `scripts/helm/destroy-one.sh` is edited by T002, T006, T009, T010, T011, T013, T015, T016, T018 →
  these run **sequentially**.
- `isolated_release_delete.feature` and `test_isolated_release_delete.py` are edited by T003/T004 and
  every `[US*]` test task → run **sequentially**.

### Parallel opportunities

- Setup: T001, T002, T003 together.
- Foundational: T005 alongside Setup.
- Polish: T021, T022 together.

---

## Implementation Strategy

### MVP first

1. Phase 1 (Setup) → 2. Phase 2 (Foundational guard) → 3. Phase 3 (US1) → **STOP & validate**:
   by-name deletion with the guard, no env-wide cleanup. This is a shippable MVP.

### Incremental delivery

US1 (MVP) → US2 (picker) → US3 (dry-run + dependents) → US4 (--yes automation) → US5 (lib docs).
Each story is an independently testable `@offline` increment; run `mise run verify:offline` after each.

---

## Notes

- `[P]` = different files, no incomplete-task dependency.
- Test-first: within each story, write the scenario + steps before the implementation task and
  confirm they fail.
- Commit after each task or logical group; ship under `feat(scripts)` / `test(...)` scopes
  (release-silent per the constitution).
- Deferred (out of scope here, tracked on issue #30): stronger prod type-to-confirm, hardened
  multi-match selector safety, richer "already absent" UX, and #29's own implementation.
