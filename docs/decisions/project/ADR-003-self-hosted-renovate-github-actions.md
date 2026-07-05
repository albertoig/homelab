# ADR-003: Self-host Renovate via scheduled GitHub Actions

- **Date**: 2026-07-04
- **Status**: Proposed
- **Deciders**: albertoig
- **Category**: project

## Context

The repo has been configured for [Renovate](https://docs.renovatebot.com/) for some
time — `renovate.json` tracks helmfile charts, `.mise.toml` tool pins, GitHub Actions,
npm, pre-commit, poetry, and the k3s version, and the README advertises "renovate
enabled". But Renovate has **never actually run**: no onboarding PR, no `renovate/*`
branches, no dependency PRs, no Dependency Dashboard (issue #40). The config alone does
nothing — something has to execute Renovate against the repo.

Dependabot is partially active (a `dependabot/pip/...` branch exists via GitHub's default
security-updates), but Dependabot cannot see this repo's largest dependency surface:
Helm/helmfile chart versions and `.mise.toml` tool pins. Renovate is the only option that
covers the whole stack, so replacing it is not attractive. The open question is only *how*
to run Renovate.

## Decision

Run Renovate **self-hosted** from a scheduled GitHub Actions workflow
(`.github/workflows/renovate.yml`) using `renovatebot/github-action`, reusing the existing
`renovate.json` unchanged. The workflow wakes on a weekday cron (and `workflow_dispatch`),
restricted to this repo, and authenticates with a `RENOVATE_TOKEN` repository secret. PRs
continue to target `beta`.

## Alternatives Considered

### Option A: Install the Mend-hosted Renovate GitHub App

- **Description**: Install the marketplace app and grant it access to the repo.
- **Pros**:
  - Zero maintenance — no workflow, no token to rotate.
  - Same `renovate.json`, same behaviour.
- **Cons**:
  - Grants a third-party SaaS app write access to the repo.
  - Activation lives outside the repo (account settings), invisible to `git`; exactly
    why the current breakage went unnoticed.
  - Less control over version, schedule, and run environment.

### Option B: Self-hosted Renovate via scheduled GitHub Actions (chosen)

- **Description**: A workflow in-repo runs `renovatebot/github-action` on a cron.
- **Pros**:
  - Activation is version-controlled and reviewable — the workflow *is* the setup.
  - No third-party app install; runs on GitHub-hosted runners we already use.
  - Full control of Renovate version (pinned, and self-updating once running), schedule,
    and log level.
- **Cons**:
  - Requires a `RENOVATE_TOKEN` secret to be created and rotated.
  - Consumes Actions minutes.

### Option C: Drop Renovate, rely on Dependabot (+ Nova / `mise outdated`)

- **Description**: Use GitHub-native Dependabot for what it supports and bolt on other
  tools for the rest.
- **Pros**:
  - Native, no token.
- **Cons**:
  - Dependabot cannot track Helm/helmfile charts or `.mise.toml` pins — the bulk of the
    stack — so it needs 2–3 extra tools to match one Renovate.
  - Throws away the working `renovate.json`.

## Consequences

### Positive

- Renovate activation is now in the repo and reviewed like any other change.
- The full dependency surface (charts, tool pins, actions, python, pre-commit) is tracked
  by a single tool again.
- Runs and schedule are transparent and tunable via the workflow.

### Negative

- A `RENOVATE_TOKEN` secret must be provisioned and eventually rotated.
- Scheduled runs consume GitHub Actions minutes.

### Risks

- **Token scope/leak**: a broad PAT is a credential. Mitigation: prefer a GitHub App
  installation token or a fine-grained PAT limited to this repo with only contents +
  pull-requests write; store as an encrypted repository secret.
- **Missing secret**: without `RENOVATE_TOKEN` the workflow fails fast — an obvious signal
  rather than silent inaction (the failure mode #40 was about).

## References

- [Issue #40 — Activate Renovate](https://github.com/albertoig/homelab/issues/40)
- [renovatebot/github-action](https://github.com/renovatebot/github-action)
- [docs/VERSIONING.md — Renovate](../../VERSIONING.md)
