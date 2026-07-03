# Implementation Plan: Ephemeral test cluster + hermetic `test` env for deep online BDD

**Branch**: `feat/35-ephemeral-test-cluster` | **Date**: 2026-07-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-ephemeral-test-cluster/spec.md`

## Summary

Enable real "deep mode" BDD for the isolated release tools (`install:one` #29, `destroy:one` #30) by
adding: (1) a `mise`-pinned ephemeral cluster tool (`kind`, podman provider) with
`cluster:test:up`/`cluster:test:down` tasks producing a dedicated `kind-homelab-test` context; (2) a
hermetic `test` Helmfile environment of trivial, dependency-free releases; (3) `@online` pytest-bdd
scenarios that perform the real sync/delete against the ephemeral cluster and assert effect +
isolation, self-discovering targets and refusing any `homelab-<env>` context; and (4) a fix so the
shared library's cluster cross-check uses the target environment's kube context, not the active one.
`@offline` stays green and cluster-free; `@online` remains excluded from the default CI run.

## Technical Context

**Language/Version**: Bash (mise tasks/scripts), YAML (helmfile), Python 3.12 `pytest-bdd` ^7.3.

**Primary Dependencies**: `kind` (NEW, mise/aqua), `helmfile`, `helm`, `kubectl`, `gum`, `jq`, `yq`,
podman (host runtime).

**Storage**: N/A. The ephemeral cluster is disposable; no persistence beyond a test run.

**Testing**: pytest-bdd under `tests/features/`. `@offline` = file/task inspection + stubbed runs (no
cluster). `@online` = real runs against the `kind-homelab-test` cluster and the `test` env.

**Target Platform**: Linux maintainer workstation (podman) and, optionally, GitHub Actions.

**Project Type**: CLI / operational automation + test infrastructure.

**Performance Goals**: Cluster up + `test` sync in well under a minute for a fast inner loop.

**Constraints**: Never touch `homelab-<env>`; `@online` must skip without a test cluster; `@offline`
stays cluster-free and in CI; no secrets required for the `test` env.

**Scale/Scope**: One new tool, two mise tasks, one `test` helmfile env + a trivial chart, `@online`
step implementations for two features + a small cluster feature, and one lib fix.

## Constitution Check

| Principle | Compliance |
|-----------|------------|
| I. Helmfile is the source of truth | **PASS** — the `test` env is defined in the principal helmfile; online tools resolve `-e test` exactly like dev/prod. |
| II. Bash + gum, reuse `scripts/lib/` | **PASS** — new mise tasks + reuse of `lib/*`; the context fix lives in the shared `lib/helmfile.sh`. |
| III. Test-first, BDD as the contract | **PASS** — spec + BDD authored before code; `@online` scenarios replace the skip placeholders and map 1:1 to spec scenarios. |
| IV. dev/prod + prod safety | **PASS** — the feature's whole point is to test **off** dev/prod; the context guard forbids running online against homelab. |
| V. Secrets never in git | **PASS** — the `test` env is secret-free and dependency-free; no decryption occurs. |
| Toolchain via mise | **PASS** — `kind` pinned via mise; no global installs. |
| ADR required | **CONSIDER** — a short ADR/note on "ephemeral kind cluster + hermetic test env for online BDD" may be added to `docs/decisions/` if the index warrants it. |
| Conventional Commits / release rules | **PASS** — ships under `test(...)`/`feat(scripts)`/`docs(...)` scopes (release-silent). |

No violations — Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/004-ephemeral-test-cluster/
├── plan.md · spec.md · research.md · data-model.md · quickstart.md
├── contracts/
│   └── test-cluster-and-env.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
.mise.toml                       # NEW: [tools] kind; [tasks] cluster:test:up / cluster:test:down
helmfile.yaml.gotmpl             # EDIT: add `test` environment
helmfile/
├── environments/test/           # NEW: test env values (dependency-free)
└── releases/NNN-test.helmfile.yaml.gotmpl   # NEW: trivial test release group
charts/test-app/                 # NEW: trivial local chart (ConfigMap/Deployment), or a vendored tiny chart

scripts/lib/helmfile.sh          # EDIT: env-scoped cluster context in cross-check helpers

tests/features/
├── ephemeral_test_cluster.feature        # NEW: cluster/test-env wiring (@offline) + create/reach/delete (@online)
├── test_ephemeral_test_cluster.py        # NEW: step defs
├── isolated_release_install.feature      # EDIT: real @online sync scenario
├── test_isolated_release_install.py      # EDIT: implement the @online steps
├── isolated_release_delete.feature       # EDIT: real @online delete scenario
└── test_isolated_release_delete.py       # EDIT: implement the @online steps

docs/SCRIPTS.md / docs/TESTING.md         # EDIT: document the ephemeral-cluster online workflow
```

**Structure Decision**: Single-repo operational-automation + test-infra layout. The `test`
environment is a first-class Helmfile environment so the isolated tools exercise the identical
`-e <env>` code path. Cluster lifecycle is expressed as mise tasks, consistent with the rest of the
repo.

## Complexity Tracking

> No constitution violations — section intentionally empty.
