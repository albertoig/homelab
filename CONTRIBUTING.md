# Contributing

Contributions are welcome. Before opening a PR, read this guide to understand the requirements.

If you want to deploy this homelab for yourself, see [docs/FORKING.md](./docs/FORKING.md) instead.

## Spec-Driven Development

This project uses [Spec Kit](https://github.com/github/spec-kit): meaningful work starts
from a written spec and plan rather than ad-hoc implementation. Conventions are codified in
the [project constitution](./.specify/memory/constitution.md), which specs must comply with.

The toolkit is committed to the repo under `.specify/` and is **AI-agent agnostic** — Spec
Kit supports Claude Code, Copilot, Gemini, Cursor, and others. Run the commands from
whichever agent you use (re-run `specify init` to add your agent's integration if it isn't
already present):

1. `/speckit-specify` — capture **what** and **why** in `specs/NNN-<slug>/spec.md`
2. `/speckit-plan` — derive the **how** into `plan.md`
3. `/speckit-tasks` — break the plan into `tasks.md`
4. `/speckit-implement` — implement, with acceptance tests

The verification loop below is plain `mise` + `pytest-bdd`, so it runs identically in
pre-commit and CI regardless of which AI agent (if any) authored the change.

### When is a spec expected?

| Write a spec first | No spec needed |
|--------------------|----------------|
| New script, chart, service, or Helmfile release | Typo / formatting / doc-only fixes |
| Change to topology, networking, or security posture | Dependency version bumps |
| A new pattern, convention, or cross-cutting workflow | One-line corrections |

Keep it lightweight — SDD should help, not bureaucratise small fixes.

### Acceptance criteria are executable (BDD)

A spec's acceptance criteria are expressed as Gherkin scenarios under `tests/features/`
(pytest-bdd), each tagged exactly one of:

- `@offline` — needs no cluster; runs locally, in **pre-commit**, and in **CI on every
  branch** (including `beta` and `main`).
- `@online` — needs a live `homelab-<env>` cluster; runs locally only.

Verify with:

```bash
mise run verify          # offline + online (online needs a cluster)
mise run verify:offline  # offline only — exactly what pre-commit and CI run
```

The `offline-bdd` pre-commit hook and the `offline-bdd` CI job both run
`mise run verify:offline`, so the offline gate is enforced before every commit and on every
branch. See [docs/TESTING.md](./docs/TESTING.md) for details.

## ADR Requirement

**Every PR that introduces a meaningful change must include an Architecture Decision Record (ADR).**

Meaningful changes include:

- Adding, removing, or replacing a service or tool
- Changing infrastructure topology or networking
- Modifying security posture (capabilities, RBAC, network policies)
- Introducing a new pattern or convention
- Changing configuration structure or deployment strategy

Trivial changes (typo fixes, formatting, minor doc updates) do not require an ADR.

### How to write an ADR

1. Determine which category your change belongs to, and create your ADR in `docs/decisions/<category>/`:
   - `helmfile/` — Helm charts, helmfile configuration, Kubernetes service deployments
   - `ansible/` — Ansible playbooks, bare metal provisioning, K3s cluster configuration
   - `project/` — Project structure, distribution model, contribution workflow

2. Find the next available number in that folder. If the highest existing ADR is `ADR-005`, yours is `ADR-006`.

3. Copy `docs/decisions/ADR-TEMPLATE.md` into the appropriate folder as `ADR-NNN-short-title.md`.

4. Fill in all sections. At minimum, the ADR must include:
   - **Context** — why the change is needed
   - **Decision** — what was decided
   - **Alternatives Considered** — at least two options with pros/cons
   - **Consequences** — positive, negative, and risks

5. Add a row to `docs/decisions/INDEX.md` in the correct category table.

6. Set the ADR status to `Proposed` in the PR. It will be updated to `Accepted` on merge.

PRs without a required ADR will be asked to add one before review.

## Commit Message Format

This project follows [Conventional Commits](https://www.conventionalcommits.org/) (Angular convention) for automatic versioning via semantic-release.

**Format**: `type(scope): description`

Use the **repo area** as the scope, not the service name. `fix(helmfile):` is correct; `fix(cert-manager):` is not — semantic-release uses the scope to decide whether to cut a release.

| Scope | Covers |
|-------|--------|
| `helmfile` | Helmfile releases, common values, templates, repositories |
| `charts` | Custom Helm charts under `charts/` |
| `metal` | Ansible playbooks and K3s provisioning under `metal/` |
| `ci` | GitHub Actions workflows |
| `pre-commit` | Pre-commit hook configuration |
| `release` | Semantic-release and versioning configuration |
| `scripts` | Scripts under `scripts/` |
| `docs` | Documentation files |

### Examples

```
feat(helmfile): add loki log aggregation stack
fix(helmfile): upgrade cert-manager from v1.20.1 to v1.20.2
feat(charts): add networkpolicy template to authentik-blueprints
chore(metal): upgrade k3s to v1.33.0
ci: update helmkit action to v1.2.0
docs(docs): add ADR for secret handling refactor
refactor(helmfile): extract shared ingress values to common template
chore(helmfile): rotate grafana secret
```

For the full rules on what triggers a release versus what is silent, see [docs/VERSIONING.md](./docs/VERSIONING.md).

## Pre-commit

It is recommended to install the pre-commit hooks to catch issues before committing:

```bash
mise run setup
```

This installs all tools, Helm plugins, and the `commit-msg` hook required for commitlint to enforce the conventional commit format locally.

Hooks that run on commit:
- **actionlint** — validates GitHub Actions workflow files
- **ansible-lint** — lints Ansible playbooks in `metal/k3s/` when those files change
- **helm-lint** — lints custom charts in `charts/` when chart files change
- **Shell BDD Tests** — runs shellspec specs when files under `scripts/` or `tests/` change
- **helmfile-lint** — lints helmfile configuration when `helmfile/` or `helmfile.yaml.gotmpl` change
- **commitlint** — enforces the conventional commit format on every commit message

## Testing

See [docs/TESTING.md](./docs/TESTING.md) for testing guidelines.

## Steps

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add an ADR if required (see above)
5. Commit using conventional commit format
6. Push and open a Pull Request
