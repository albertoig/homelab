# ADR-001: Fork-Based Model for User Configs and Secrets

- **Date**: 2026-03-31
- **Status**: Proposed
- **Deciders**: Homelab maintainers
- **Category**: infrastructure

## Context

The homelab repository contains two types of content:

1. **Shared infrastructure code**: Helm charts, common values, Helmfile release definitions, Ansible playbooks, and utility scripts. These are the same for every user.
2. **User-specific configuration**: Environment configs (domain names, IP pools, storage sizes), encrypted secrets (API keys, passwords, webhook URLs), SOPS key fingerprints, and Kubernetes context names. These differ per deployment.

Currently, both types live in the same repository. The upstream repo carries example configs (`config.template.yaml`) and encrypted secrets that only work with the maintainer's PGP key. Users who clone the repo directly cannot use the encrypted secrets and must re-initialize everything. There is no clear separation between "what to update from upstream" and "what is mine."

This creates friction:
- Users cannot easily pull infrastructure updates without risking conflicts with their config files.
- The encrypted secrets checked into the upstream repo are useless to anyone without the maintainer's PGP key.
- There is no documented workflow for how a user should maintain their own copy.

## Decision

Adopt a fork-based model where users fork the repository to store their own configs and secrets. The upstream repository serves as a template with shared infrastructure code, and each fork holds user-specific files.

## Alternatives Considered

### Option A: Keep everything in one repo (status quo)
- **Description**: Users clone the repo directly and edit configs in place.
- **Pros**:
  - Simple — no concept of upstream/fork to understand.
  - Single source of truth.
- **Cons**:
  - Pulling upstream updates risks overwriting user configs.
  - Encrypted secrets in upstream are unusable without the maintainer's PGP key.
  - No clear boundary between shared code and user-specific data.
  - Users must manually resolve conflicts on every upstream sync.

### Option B: Fork-based model with upstream sync (Selected)
- **Description**: Users fork the repo. Upstream contains shared code; forks contain user configs and secrets. A `docs/FORKING.md` documents the workflow.
- **Pros**:
  - Clear separation: upstream owns infrastructure code, forks own configs/secrets.
  - Users can pull upstream updates with `git fetch upstream && git merge` — user-specific files don't exist upstream, so they won't conflict.
  - Each fork has its own SOPS key — secrets are properly encrypted and usable.
  - Standard GitHub workflow — no new tooling required.
- **Cons**:
  - Users must understand git remotes (upstream vs origin).
  - Fork divergence if users modify shared files (common values, scripts).
  - No automated way to check if a fork is behind upstream.

### Option C: Separate config repository
- **Description**: Keep infrastructure code in one repo and user configs in a separate private repo. Helmfile pulls config from the second repo at deploy time.
- **Pros**:
  - Cleanest separation of concerns.
  - Config repo can be private while infrastructure repo stays public.
- **Cons**:
  - Adds complexity — users manage two repositories.
  - Requires a mechanism to link the config repo at deploy time (git submodule, environment variable, or script).
  - Overkill for a personal homelab.

### Option D: Helm values chart with environment overlays
- **Description**: Package configs as a Helm chart that users install separately. The infrastructure repo references it via chart dependencies.
- **Pros**:
  - Follows Helm conventions.
  - Versioned config with semantic versioning.
- **Cons**:
  - Helm is not designed for configuration management — this conflates chart packaging with runtime config.
  - Secrets would still need SOPS or a secrets manager.
  - Adds unnecessary abstraction for a flat YAML file.

## Consequences

### Positive
- Users can pull infrastructure updates without config conflicts.
- Each fork has properly encrypted secrets usable only by the fork owner.
- Standard GitHub fork/sync workflow — well-understood by most developers.
- Upstream repo stays clean — no environment-specific data.
- `docs/FORKING.md` provides a clear onboarding path.

### Negative
- Users must understand git remotes (upstream vs origin).
- If users modify shared files (scripts, common values), merging upstream requires manual conflict resolution.
- Forks may drift behind upstream if not regularly synced.

### Risks
- **Risk**: Users modify shared infrastructure files in their fork, making upstream merges difficult.
  - **Mitigation**: `docs/FORKING.md` clearly documents which files are user-specific and which are shared. PRs from forks that modify shared files should be upstreamed, not maintained in the fork.
- **Risk**: Users forget to update `.sops.yaml` with their own key, causing encryption failures.
  - **Mitigation**: `init-secrets.sh` could detect the upstream key fingerprint and warn, or `docs/FORKING.md` makes this a prominent step.

## References

- [FORKING.md](../FORKING.md) — user-facing fork setup guide
- [CONFIG.md](../CONFIG.md) — config system reference
- [SECRETS.md](../SECRETS.md) — secrets reference
