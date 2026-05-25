# Versioning

This document describes how releases are versioned, what triggers a new release, and how automated dependency updates work.

---

## Version scheme

The project follows [Semantic Versioning](https://semver.org/):

| Increment | Meaning | Example trigger |
|-----------|---------|-----------------|
| **Major** | Breaking change — migration required | Namespace rename, incompatible config structure change |
| **Minor** | New or upgraded service | New chart added, chart minor/major version bump |
| **Patch** | Non-breaking fix | Chart patch version bump, broken release config fix |

Versions are managed automatically by [semantic-release](https://semantic-release.gitbook.io/semantic-release/). No version number is ever set manually.

---

## Release branches

| Branch | Release type | Example tag |
|--------|-------------|-------------|
| `main` | Stable | `v1.2.0` |
| `beta` | Pre-release | `v1.2.0-beta.1` |

All development happens on feature branches targeting `beta`. Once `beta` is stable it is merged into `main` to produce a stable release.

---

## What triggers a release

Semantic-release reads the conventional commit history and only cuts a new release when a commit with a release-triggering type is present.

**Only two scopes trigger a release: `helmfile` and `charts`.**

| Commit | Release type |
|--------|-------------|
| `fix(helmfile): upgrade X from v1.0.0 to v1.0.1` | patch |
| `fix(charts): fix rendering bug in custom chart` | patch |
| `feat(helmfile): add X service` | minor |
| `feat(helmfile): upgrade X from v1 to v2` | minor |
| `feat(charts): add networkpolicy template` | minor |
| Any commit with `BREAKING CHANGE` in the footer | major |

The principle is that a release reflects a change to the **deployed infrastructure state**. Tooling, CI, documentation, and scripts changes never produce a release.

---

## What does NOT trigger a release

| Area | Commit type | Reason |
|------|-------------|--------|
| `docs/` | `docs:` | Documentation only |
| `.github/workflows/` | `ci:` | Pipeline changes do not affect the cluster |
| `.pre-commit-config.yaml` | `ci:` or `build:` | Tooling only |
| `package.json` devDependencies | `chore:` | Build tooling only |
| `scripts/` | `chore:` or `refactor(scripts):` | Not deployed |
| `metal/k3s/` | `chore(metal):` | Provisioning is separate from the helmfile state |
| `helmfile/environments/*/config.yaml` | `chore(helmfile):` | Env tuning without a chart version change |
| `helmfile/environments/*/secrets/` | `chore(helmfile):` | Secret rotation |
| `helmfile/repositories.yaml` | `chore(helmfile):` | Repo additions are prep work |
| `helmfile/locks/` | `chore(helmfile):` | Auto-generated |
| `helmfile/secret-templates/` | `chore(helmfile):` | Local setup templates |
| `helmfile/config.template.yaml` | `docs:` | User-facing template |
| Values file refactor (no behaviour change) | `refactor(helmfile):` | Structure change only |
| `renovate.json` | `ci:` | Dependency automation config |
| `versions.yaml` — CI tooling only (node, python, ansible) | `chore:` | These do not affect the cluster |

> **Exception — `versions.yaml` infrastructure entries:** `helm`, `helmkit`, `ansible_core`, `ansible_lint`, `ansible_posix` in `versions.yaml` are treated identically to helmfile chart versions. Renovate uses `fix(helmfile):` for patch bumps and `feat(helmfile):` for minor/major bumps on these entries, so they do trigger releases.

---

## Automated dependency updates — Renovate

[Renovate](https://docs.renovatebot.com/) runs on a weekday schedule and opens pull requests to `beta` when new versions are available. It uses the same commit conventions as manual commits so that releases are cut correctly.

### What Renovate tracks

| Dependency type | Source | Commit type |
|----------------|--------|-------------|
| Helm chart versions (`helmfile/releases/`) | Helm registries | `fix/feat(helmfile):` |
| `versions.yaml` — `helm`, `helmkit` | GitHub Releases | `fix/feat(helmfile):` |
| `versions.yaml` — `ansible_core`, `ansible_lint` | PyPI | `fix/feat(helmfile):` |
| `versions.yaml` — `ansible_posix` | Ansible Galaxy | `fix/feat(helmfile):` |
| `versions.yaml` — `node` | Node.js releases | `fix/feat(helmfile):` |
| `versions.yaml` — `python` | Python releases | `fix/feat(helmfile):` |
| GitHub Actions (`uses:`) | GitHub Releases | `chore(ci):` |
| npm devDependencies | npm registry | `chore:` |
| Pre-commit hook revisions | GitHub Releases | `chore(pre-commit):` |
| `metal/k3s/inventory.example.yml` k3s version | GitHub Releases | `chore(metal):` |

### Renovate behaviour

- PRs open against `beta`, not `main`
- A minimum age of 3 days is enforced before a PR is created (avoids yanked releases)
- Pre-releases are ignored for `helmfile` and `custom.regex` managers
- Major version bumps automatically include `BREAKING CHANGE` in the commit body

### Updating `helmkit` in CI

`helmkit` is tracked in `versions.yaml` and Renovate will open a PR bumping that entry. However, the `uses: docked-titan-foundation/helmkit@vX.Y.Z` line in `.github/workflows/validate.yml` **must be updated manually** to match, because GitHub Actions does not support expressions in `uses:` fields. Both changes should be in the same PR.

---

## Changelog

The `CHANGELOG.md` at the repo root is generated automatically by semantic-release on every release. Do not edit it by hand — any manual changes will be overwritten on the next release.

---

## Checking the current release state

```bash
# Latest stable release
git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*beta*'

# Latest release including beta
git describe --tags --abbrev=0
```
