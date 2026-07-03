---
description: "Task list for ephemeral test cluster + hermetic test env + deep online BDD (issue #35)"
---

# Tasks: Ephemeral test cluster + hermetic `test` env for deep online BDD

**Input**: Design documents from `specs/004-ephemeral-test-cluster/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/test-cluster-and-env.md, quickstart.md

**Tests**: INCLUDED — BDD is the contract (Principle III). Scenarios are authored per story, before
that story's implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: US1–US4 from spec.md

---

## Phase 1: Setup

- [ ] T001 [P] Add `kind` to `.mise.toml` `[tools]` (aqua `kubernetes-sigs/kind`); `mise install`.
- [ ] T002 [P] Create `tests/features/ephemeral_test_cluster.feature` with the Feature header and
  `@offline` (wiring/inspection) + `@online` (create/reach/delete) scenario blocks.
- [ ] T003 Create `tests/features/test_ephemeral_test_cluster.py`:
  `scenarios("ephemeral_test_cluster.feature")`, `repo_root` fixture, generic file/task assertions,
  and the online skip/guard helpers (skip unless the `kind-homelab-test` context is reachable; refuse
  `homelab-<env>`). *(depends on T002)*

---

## Phase 2: Foundational

- [ ] T004 [P] [US1] Add `[tasks."cluster:test:up"]` and `[tasks."cluster:test:down"]` to
  `.mise.toml`: up creates the `kind-homelab-test` cluster with the podman provider and waits ready;
  down deletes it. Neither touches any `homelab-<env>` context.
- [ ] T005 [P] [US2] Add the trivial local chart `charts/test-app/` (a `ConfigMap`/`Deployment`, no
  external deps, no secrets) and a `helmfile/releases/NNN-test.helmfile.yaml.gotmpl` release group.
- [ ] T006 [US2] Add the `test` environment to `helmfile.yaml.gotmpl` and
  `helmfile/environments/test/` values, defining **≥2** trivial releases (for isolation asserts),
  with `kubeContext: kind-homelab-test`. *(depends on T005)*

**Checkpoint**: A disposable cluster can be created and a hermetic `test` env can be listed/synced.

---

## Phase 3: User Story 1 - Disposable test cluster (P1)

- [ ] T007 [US1] Add US1 scenarios + steps to `ephemeral_test_cluster.(feature|py)`: `@offline`
  assert the tool is pinned and the up/down tasks exist and target a test-only context; `@online`
  create → `kubectl` reachable → delete; assert no `homelab-<env>` context is touched. *(depends on T003, T004)*

---

## Phase 4: User Story 2 - Hermetic `test` env (P1)

- [ ] T008 [US2] Add US2 scenarios + steps: `@offline` assert `helmfile -e test list` (stubbed/real)
  yields only trivial releases and the env is declared; `@online` sync the `test` releases onto the
  ephemeral cluster and assert they deploy with no external deps/secrets. *(depends on T003, T006)*

---

## Phase 5: User Story 3 - Deep @online BDD for install:one and destroy:one (P1) 🎯

- [ ] T009 [US3] Replace the `install:one` `@online` skip in `isolated_release_install.(feature|py)`
  with a real scenario: with the `test` releases deployed, `install:one test <release> --yes` syncs
  the target and leaves a sibling unchanged; self-discover target/sibling; skip without a test
  cluster; refuse `homelab-<env>`. *(depends on T007, T008)*
- [ ] T010 [US3] Replace the `destroy:one` `@online` skip in `isolated_release_delete.(feature|py)`
  with a real scenario: `destroy:one test <release> --yes` removes the target and leaves a sibling
  running; same discovery/skip/guard. *(depends on T007, T008)*

---

## Phase 6: User Story 4 - Env-scoped cluster cross-check fix (P2)

- [ ] T011 [US4] Add a scenario/assert (offline where possible) that the cluster cross-check uses the
  target env's context, then implement it in `scripts/lib/helmfile.sh`: resolve the env's
  `kubeContext` and pass `--kube-context` to `helm` in `helmfile_cluster_releases`/`_keys`. Keep the
  existing offline stubs passing. *(depends on T003)*

---

## Phase 7: Polish & Cross-Cutting

- [ ] T012 [P] Document the ephemeral-cluster online workflow in `docs/SCRIPTS.md` / `docs/TESTING.md`
  (`cluster:test:up` → `verify` online → `cluster:test:down`), including the podman note.
- [ ] T013 Run `mise run verify:offline` + `mise run lint`; ensure `@offline` is green and cluster-free.
- [ ] T014 Run the full online flow locally: `cluster:test:up` → online scenarios pass → `cluster:test:down`.

---

## Dependencies & Execution Order

- Setup (T001–T003) → Foundational (T004–T006) → US1 (T007) / US2 (T008) → US3 (T009–T010) → US4
  (T011) → Polish (T012–T014).
- **Critical path**: T004 + T006 → T007/T008 → T009/T010 → T014.

### Same-file serialization

- `.mise.toml` edited by T001, T004 → sequential.
- `helmfile.yaml.gotmpl` edited by T006 (and chart/release by T005) → sequential within US2.
- Each isolated feature's `.feature`/`.py` edited by its `@online` task → sequential.

---

## Notes

- Test-first: author each scenario before its implementation.
- Ship under `test(...)` / `feat(scripts)` / `docs(...)` scopes (release-silent per the constitution).
- Tool choice (`kind`) is swappable to `minikube` via the single `[tools]` entry + the up/down tasks;
  the BDD steps only require a reachable test context.
