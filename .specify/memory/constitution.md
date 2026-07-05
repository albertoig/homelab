<!--
Sync Impact Report
- Version change: 1.2.0 → 1.2.1 (PATCH)
- Bump rationale: Clarifies/refines the existing "Release bump rules" with an explicit
  rule for adding vs. updating Helmfile software. No new principle, no redefinition —
  makes an existing convention (new chart = minor via feat(helmfile)) unambiguous.
- Modified sections:
  - Additional Constraints → "Release bump rules": added two bullets — adding new
    software = minor/feat (never breaking merely for being new); updating existing =
    patch/minor per the fix/feat rules.
- Added sections: none
- Removed sections: none
- Templates / docs checked:
  - .specify/templates/plan-template.md — ✅ no change (no release-bump references)
  - .specify/templates/spec-template.md — ✅ no change
  - .specify/templates/tasks-template.md — ✅ no change
  - docs/VERSIONING.md — ✅ already consistent (Minor = new or upgraded service)
- Follow-up TODOs: none
-->

# Homelab Constitution

This constitution captures the non-negotiable conventions of the homelab platform
repository. It is the source of truth that `/speckit-*` specs, plans, and tasks must
comply with. Specs that contradict a principle here must either be revised or amend
this document (see Governance).

## Core Principles

### I. Helmfile Is the Source of Truth
All Kubernetes service deployment is declared through Helmfile, in the five staged
releases under `helmfile/releases/` (CRDs → Certificates → Blueprints → Core Apps →
Ingresses). Shared values and templates live in `helmfile/common/`; per-environment
configuration in `helmfile/environments/<env>/`. Do not deploy services by applying raw
manifests out of band — if it runs in the cluster, it is described in Helmfile (or
delivered by ArgoCD from a downstream repo). This repository manages **platform
infrastructure only**; application workloads belong in downstream repos deployed via
ArgoCD.

### II. Bash + gum Scripting, Reuse the Shared Library
Operational automation is POSIX-friendly Bash orchestrated through `mise` tasks. User
interaction uses `gum`. Scripts MUST reuse the shared helpers in `scripts/lib/`
(`env.sh`, `secrets.sh`, `colors.sh`, `headers.sh`, `openbao.sh`, …) rather than
re-implementing environment selection, secret loading, or output formatting. New
behavior belongs in a `scripts/<area>/` script wired to a `mise` task, not inline in
CI or docs.

### III. Test-First, BDD as the Contract (NON-NEGOTIABLE)
Behavior is specified before or alongside implementation and expressed as executable
tests:
- **Shell behavior** → shellspec specs under `tests/shell/`, mirroring `scripts/`, run
  inside a sandboxed `PATH` of stubs (see `tests/shell/scripts/infra/preflight_spec.sh`).
- **Acceptance criteria** → Gherkin `.feature` files under `tests/features/`, executed
  with `pytest-bdd`. Each `/speckit-specify` spec's acceptance criteria SHOULD map to a
  scenario.

**Every scenario carries exactly one of two tags**, and this split is mandatory:
- `@offline` — needs no cluster (inspects files, configs, rendered output, stubbed
  commands). Runs **everywhere**: locally and in CI, on **every branch including `beta`
  and `main`**.
- `@online` — needs a reachable `homelab-<env>` cluster. Runs **locally only**.

Two entry points enforce the split:
- `mise run verify` → the local full check: runs `@offline`, then brings up the disposable
  ephemeral test cluster, runs the `@online` scenarios against it, and tears it down (via
  `verify:online`). This is the only entry point that provisions a cluster.
- `mise run verify:offline` → runs **only** `@offline`. This is the exact command the
  **GitHub pipeline runs on every branch**; CI never runs `@online` scenarios (it has no
  cluster).

The offline gate is enforced in **three** places and must pass in all of them:
- **pre-commit** — the `offline-bdd` hook runs `mise run verify:offline` when specs,
  feature files, or the verify wiring change, blocking the commit on failure.
- **CI** — `validate.yml` runs `mise run verify:offline` on every branch (reaching
  `main`/`beta` via `release.yml`'s `workflow_call`).
- **local full check** — `mise run verify` additionally runs `@online` scenarios when
  cluster-facing behavior changed.

(The legacy pytest suites under `tests/smoke/` and `tests/k8s/` predate this model and are
being migrated to `@online` scenarios; they are not part of the `verify` loop.)

### IV. dev/prod Environment Model with Prod Safety
Two environments exist: `dev` (default) and `prod`. The active environment is selected
via `scripts/lib/env.sh` (argument, `ENV` var, or interactive prompt) — never hardcoded.
Any destructive or production-affecting action (`destroy`, prod secret writes, prod
Terraform apply, OpenBao operations against prod) MUST require explicit confirmation and
support a non-interactive `--yes` only when deliberately automated. Default to the safe
path; make the dangerous path loud.

### V. Secrets Never Land in Git
Bootstrap secrets are SOPS-encrypted (`*.enc.yaml`); runtime secrets are issued by
OpenBao via the External Secrets Operator. Plaintext secrets, tokens, or kubeconfigs are
never committed. Lint and tests must run without real secrets — use the stub
`helmfile/environments/lint-values.yaml` for `helmfile lint`, and tool stubs for shell
specs. `.claude/settings.local.json` and other local/credential artifacts stay
gitignored.

### VI. Never Bypass the Commit Gates (NON-NEGOTIABLE)
The pre-commit hooks are a hard gate, not a suggestion. Under **no circumstance** may a
commit skip them: `git commit --no-verify` / `-n`, `SKIP=<hook>`, `--no-hooks`, disabling
or uninstalling hooks, or any other bypass is **forbidden** — including for humans, agents,
CI, and "just this once" fixes. This holds even when a failing hook trips on something
unrelated to the change: the correct response is to **fix the underlying cause** (e.g. clean
up the stray artifact, repair the broken chart, or amend the hook itself in the same or a
prior commit) so the gate passes honestly, never to route around it. A red hook blocks the
commit until the tree is genuinely green. If a hook is wrong, fix the hook — do not skip it.

### VII. Cascading Changes Must Propagate to Specs and Tests
When a change triggers subsequent, consequential breaking changes elsewhere — a chain
reaction where fixing one thing forces edits to others — that ripple MUST NOT be absorbed
silently in code alone. Because the specs (`specs/NNN-<slug>/`) and BDD scenarios
(`.feature` files + step definitions) are the contract (Principle III), a cascade that
leaves them stale makes the contract lie. In that situation you MUST **surface the full
blast radius and suggest the corresponding updates** to every affected spec and BDD test,
alongside the code change, so reviewers see the whole chain rather than a code-only patch
with drifted documentation. Do not quietly "make it compile"; keep the spec, the tests, and
the code telling the same story.

## Additional Constraints

- **Toolchain via mise.** All tools and versions are pinned in `.mise.toml`; contributors
  bootstrap with `mise run setup`. Do not assume globally installed tools.
- **Spec-Driven Development.** Meaningful work starts from a spec (`specs/NNN-<slug>/`)
  produced via the `/speckit-*` flow. See the threshold in Development Workflow.
- **Architecture Decision Records.** Meaningful changes require an ADR under
  `docs/decisions/<category>/` with an `INDEX.md` row (see `CONTRIBUTING.md`).
- **Conventional Commits (Angular preset).** Messages follow `type(scope): description`
  using the **repo area** as scope (`helmfile`, `charts`, `metal`, `ci`, `scripts`,
  `docs`, …), enforced by commitlint. Versioning is automated by semantic-release using
  the **angular** preset; the commit `type` + `scope` determines whether a release is cut,
  so the format must be chosen deliberately, not cosmetically.
- **Release bump rules (source of truth: the semantic-release config in `package.json`
  → `release.plugins[@semantic-release/commit-analyzer].releaseRules`; see also
  `docs/VERSIONING.md`).** The scope decides the bump:
  - A **breaking change** (`!` after type, or a `BREAKING CHANGE:` footer) → **major**,
    regardless of scope.
  - `feat(helmfile)` / `feat(charts)` → **minor**.
  - `fix(helmfile)` / `fix(charts)` → **patch**.
  - **Adding new software** — a new Helmfile release/chart under `helmfile/releases/` — is
    **additive**: it MUST bump the version as a **minor** via `feat(helmfile)`, and MUST NOT
    be classed as a breaking/major change merely for being new. Reserve `major` for a change
    that actually forces migration of existing deployed state (e.g. a namespace rename or an
    incompatible config restructure), not for the mere presence of a new release.
  - **Updating existing software** MUST also bump the version, per the rules above: a chart
    **patch** bump → `fix(helmfile)` (patch), a chart **minor/major** bump → `feat(helmfile)`
    (minor). An update is only `major` when it carries a genuine `BREAKING CHANGE:`.
  - **Every other `feat`/`fix` scope is silent** (`release: false`) — e.g.
    `feat(scripts)`, `fix(ci)`, `fix(metal)` do **not** cut a release.
  - Other types (`chore`, `docs`, `refactor`, `test`, `ci`, …) are silent unless they
    carry a breaking change.
  Use the scope that reflects what actually shipped: only changes to deployed platform
  state (`helmfile`, `charts`) should trigger a version bump. Releasing or staying silent
  is a deliberate choice encoded in the commit — pick the scope accordingly.

## Development Workflow

**When a spec is expected (write `specs/NNN-<slug>/spec.md` first):**
- A new script, chart, service, or Helmfile release
- A change to infrastructure topology, networking, or security posture
- A new pattern, convention, or cross-cutting workflow

**When a spec is NOT required (just do it, with a test if behavior changes):**
- Typo/formatting/doc-only fixes, dependency bumps, one-line corrections

**The flow** (kept lightweight — SDD must help, not bureaucratise):
1. `/speckit-specify` — capture **what** and **why** in `specs/NNN-<slug>/spec.md`.
2. `/speckit-plan` — derive the **how** into `plan.md`, consistent with this constitution.
3. `/speckit-tasks` — break the plan into `tasks.md`.
4. `/speckit-implement` — implement, with shellspec/pytest-bdd acceptance tests.
5. Verify: `mise run verify` (lint + shellspec + offline BDD) must pass; cluster tests
   run against a deployed env when relevant. Add the ADR. Open a PR.

## Governance

This constitution supersedes ad-hoc practice. PRs and reviews should verify compliance;
deviations must be justified in the PR (and, when they introduce a new convention,
recorded as an ADR). Amendments are made by editing this file in a PR that explains the
change and bumps the version below (semantic: MAJOR for principle removal/redefinition,
MINOR for a new principle or section, PATCH for clarifications).

**Version**: 1.2.1 | **Ratified**: 2026-06-29 | **Last Amended**: 2026-07-04
