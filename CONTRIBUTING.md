# Contributing

Contributions are welcome. Before opening a PR, read this guide to understand the requirements.

If you want to deploy this homelab for yourself, see [docs/FORKING.md](./docs/FORKING.md) instead.

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

1. Determine which category your change belongs to:
   - `helmfile/` — Helm charts, helmfile configuration, Kubernetes service deployments
   - `ansible/` — Ansible playbooks, bare metal provisioning, K3s cluster configuration

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

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`

**Examples**:
- `feat(helmfile): add prometheus monitoring stack`
- `fix(cert-manager): resolve certificate renewal issue`
- `docs(readme): update installation instructions`

## Steps

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add an ADR if required (see above)
5. Commit using conventional commit format
6. Push and open a Pull Request
