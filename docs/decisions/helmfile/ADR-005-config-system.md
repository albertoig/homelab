# ADR-005: Per-Environment Config System for User-Configurable Settings

- **Date**: 2026-03-31
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: infrastructure

## Context

User-configurable settings (domain names, IP pools, storage sizes, replica counts, retention periods) were scattered across multiple files:

- Domain names hardcoded in `helmfile/environments/<env>/values/grafana.yaml.gotmpl`, `argocd.yaml.gotmpl`, `longhorn.yaml.gotmpl`, `authentik-ingress.yaml.gotmpl` (e.g., `grafana.internal.iglesias.cloud` appeared 5+ times)
- MetalLB IP ranges in `metallb-config.yaml.gotmpl`
- Prometheus retention/storage in `prometheus-stack.yaml.gotmpl`
- DNS provider hardcoded in `common/values/external-dns.yaml.gotmpl`

This meant:
1. **Onboarding friction**: A new user had to hunt through 10+ files to customize their deployment.
2. **Duplication**: The same domain string appeared in multiple places per environment.
3. **Separation of concerns**: Secrets were well-organized (per-chart templates, SOPS encryption), but non-secret config had no equivalent structure.
4. **Per-env values proliferation**: Most per-environment values files existed solely to override hardcoded defaults with environment-specific values.

## Decision

Introduce a per-environment `config.yaml` file that centralizes all non-secret, user-configurable settings. Common values files (`helmfile/common/values/*.yaml.gotmpl`) read from this config using helmfile's `readFile`/`fromYaml` functions. Per-environment values files are eliminated or reduced to minimal overrides.

## Alternatives Considered

### Option A: Keep scattered values (status quo)
- **Description**: Leave domain names and config values in per-environment values files.
- **Pros**:
  - No changes needed.
  - Existing structure is familiar.
- **Cons**:
  - New users must edit 10+ files to customize their deployment.
  - Domain name changes require updating every ingress-related file.
  - No clear separation between "user config" and "chart implementation details".

### Option B: Helmfile state values (Selected)
- **Description**: Use `helmfile/environments.yaml.gotmpl` to load config as state values via `helmDefaults` or environment-level `values`.
- **Pros**:
  - Native helmfile mechanism.
- **Cons**:
  - State values are flat key-value pairs, not nested YAML.
  - Awkward for complex config structures.
  - Doesn't integrate cleanly with gotmpl values files.

### Option C: Per-environment config.yaml with readFile/fromYaml (Selected)
- **Description**: Create `helmfile/environments/<env>/config.yaml` with structured YAML. Common values files read it via `readFile` at the top of each gotmpl file.
- **Pros**:
  - Structured YAML with sections (`general:`, `metallb:`, `grafana:`, etc.).
  - Mirrors the existing secrets template pattern (`config.template.yaml` as source of truth).
  - Non-secret values are committed to git (reviewable, diffable).
  - Common values files become fully self-contained — no per-env overrides needed.
  - Single file to edit when customizing a deployment.
- **Cons**:
  - `readFile` path depends on the gotmpl file's location (common values use `../../environments/`, env values use `../`).
  - Requires helmfile gotmpl support (already in use).

### Option D: Top-level config.yaml with environment sections
- **Description**: Single `config.yaml` at repo root with `dev:` and `prod:` sections.
- **Pros**:
  - All config in one file.
  - Easy to compare environments.
- **Cons**:
  - Breaks the per-environment directory convention used for secrets and values.
  - Harder to manage as config grows.
  - Can't use `.gitignore` patterns per environment.

## Consequences

### Positive
- **Single source of truth**: All user-configurable settings in one file per environment.
- **Reduced values files**: Per-environment values files reduced from 7 to 0-1 (only true per-env overrides like `ingress.enabled: false` remain).
- **Self-documenting**: `config.template.yaml` serves as reference with descriptions and defaults.
- **Easy onboarding**: New users copy the template, edit one file, and deploy.
- **Consistent pattern**: Config system mirrors the existing secrets system (template → per-env file → consumed by gotmpl).

### Negative
- **Path resolution**: `readFile` paths differ between common values (`../../environments/`) and env values (`../`). New contributors must understand this.
- **Gotmpl coupling**: Config values are only available in gotmpl files. Plain YAML values files cannot read config.
- **No validation**: Invalid config values (e.g., malformed IP range) are only caught at deploy time, not earlier.

### Risks
- **Risk**: A missing `config.yaml` causes helmfile to fail with a confusing `readFile` error.
  - **Mitigation**: `config.template.yaml` exists as a starting point. The error message clearly indicates the missing file path.

## Implementation

- `helmfile/config.template.yaml` — template with all options, descriptions, and defaults.
- `helmfile/environments/<env>/config.yaml` — per-environment config (committed, non-secret).
- `helmfile/common/values/*.yaml.gotmpl` — read config via `readFile`/`fromYaml`, reference values as `$cfg.<section>.<key>`.
- Per-environment `values/` directories — eliminated or reduced to minimal overrides.

## References

- [CONFIG.md](../CONFIG.md) — config system reference documentation
- [SECRETS.md](../SECRETS.md) — parallel system for encrypted values
