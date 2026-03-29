# ADR-001: Migrate Loki to grafana-community Chart

- **Date**: 2026-03-29
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: monitoring

## Context

The Loki deployment was using the `grafana/loki` Helm chart at version `6.54.0`. The official Grafana Loki chart (`grafana/loki`) has been deprecated in favor of the community-maintained chart under `grafana-community/loki`. The community chart tracks newer Loki releases, including the major v9 line, and receives active maintenance and feature updates.

Running on a deprecated chart means:
- No access to Loki v9 features (multi-tenant improvements, performance optimizations, native OpenTelemetry support).
- Security patches may stop being backported.
- Growing divergence from the upstream Helm ecosystem.

## Decision

Migrate from `grafana/loki` v6.54.0 to `grafana-community/loki` v9.2.2.

## Alternatives Considered

### Option A: Stay on grafana/loki v6
- **Description**: Remain on the deprecated official chart.
- **Pros**:
  - No migration effort required.
  - Existing configuration continues to work unchanged.
- **Cons**:
  - Locked out of Loki v9 features and fixes.
  - Deprecated chart may lose security patches.
  - Increasing incompatibility with newer ecosystem tooling (Alloy, Grafana 11+).

### Option B: Migrate to grafana-community/loki v9 (Selected)
- **Description**: Switch to the actively maintained community chart.
- **Pros**:
  - Access to Loki v9 with improved multi-tenancy, compaction, and query performance.
  - Native OpenTelemetry log ingestion support.
  - Active maintenance and security updates.
  - Better alignment with Grafana ecosystem (Alloy, Tempo).
- **Cons**:
  - Chart values schema changed between v6 and v9; configuration review required.
  - Breaking changes in Loki v9 require testing (e.g., `auth_enabled` defaults, storage config).

## Consequences

### Positive
- Loki deployment is on an actively maintained chart.
- Multi-tenant support via `X-Scope-OrgID` header becomes available.
- Compatibility with Alloy's `loki.write` component for log shipping.
- Future-proof for upcoming Loki features.

### Negative
- Requires configuration changes to Grafana datasource (adding `X-Scope-OrgID` header).
- Lock files for both dev and prod environments must be regenerated.

### Risks
- **Risk**: Existing stored logs may require re-indexing or manual migration during upgrade.
  - **Mitigation**: Test upgrade on dev environment first; Longhorn-backed storage ensures data persistence across pod restarts.

## Configuration Changes

- `helmfile/common/common.yaml.gotmpl`: chart reference and version updated.
- `helmfile/common/values/grafana.yaml.gotmpl`: added `X-Scope-OrgID` header to Loki datasource.
- Lock files regenerated for dev and prod.

## References

- [grafana-community/loki Helm chart](https://artifacthub.io/packages/helm/grafana-community/loki)
- [Loki v9 release notes](https://grafana.com/docs/loki/latest/release-notes/)
- [grafana/loki deprecation notice](https://github.com/grafana/loki/blob/main/production/helm/loki/README.md)
