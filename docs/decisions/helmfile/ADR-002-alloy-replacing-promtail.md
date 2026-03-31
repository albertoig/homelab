# ADR-002: Replace Promtail with Alloy for Log Collection

- **Date**: 2026-03-29
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: monitoring

## Context

Log collection in the cluster was handled by Promtail, Grafana's legacy log shipping agent. Promtail is limited to Loki-specific log ingestion and has entered maintenance mode. Grafana has introduced Alloy as its next-generation telemetry collector, built on OpenTelemetry, which provides a unified pipeline for logs, metrics, and traces.

With the Loki migration to v9 (see [ADR-001](ADR-001-loki-grafana-community-migration.md)), the ecosystem naturally favors Alloy as the log collection agent due to its native `loki.write` component and better integration with the Grafana stack.

## Decision

Replace Promtail with Alloy deployed as a DaemonSet for log collection across all cluster nodes.

## Alternatives Considered

### Option A: Keep Promtail
- **Description**: Continue using Promtail for log collection.
- **Pros**:
  - No changes to existing pipeline.
  - Well-understood configuration.
- **Cons**:
  - Promtail is in maintenance mode; no new features.
  - Limited to Loki-only log ingestion.
  - No native OpenTelemetry support.
  - May become incompatible with future Loki releases.

### Option B: Use OpenTelemetry Collector directly
- **Description**: Deploy the generic OpenTelemetry Collector with Loki exporter.
- **Pros**:
  - Vendor-neutral, fully OpenTelemetry-native.
  - Supports logs, metrics, and traces.
- **Cons**:
  - More complex configuration for Loki-specific pipelines.
  - Requires manual setup of Loki exporter and service discovery.
  - Less tight integration with Grafana ecosystem.

### Option C: Use Alloy (Selected)
- **Description**: Deploy Grafana Alloy as a DaemonSet with Loki sink.
- **Pros**:
  - Native Grafana ecosystem integration.
  - Built-in `loki.source.kubernetes` and `loki.write` components.
  - Supports OpenTelemetry pipelines for future metrics/traces expansion.
  - Actively developed with Prometheus and Grafana backing.
  - ServiceMonitor support for self-monitoring.
- **Cons**:
  - Newer tool; community resources less abundant than Promtail.
  - Alloy-specific configuration syntax to learn.

## Consequences

### Positive
- Unified telemetry collector ready for future metrics/traces via OpenTelemetry.
- Native Kubernetes pod discovery and log tailing via `loki.source.kubernetes`.
- DaemonSet deployment ensures logs are collected from every node.
- ServiceMonitor enables Prometheus scraping for Alloy's own metrics.

### Negative
- Promtail values file (`promtail.yaml.gotmpl`) becomes unused and should be removed.
- Alloy configuration uses a custom Alloy syntax (not pure OTel Collector config).

### Risks
- **Risk**: Alloy DaemonSet may consume more resources than Promtail.
  - **Mitigation**: Monitor resource usage via Alloy's ServiceMonitor; set resource limits if needed.

## Configuration

Alloy is deployed as a DaemonSet with the following pipeline:

1. **Discovery**: `discovery.kubernetes "pods"` discovers all pods in the cluster.
2. **Collection**: `loki.source.kubernetes "pods"` tails pod logs.
3. **Shipping**: `loki.write "default"` pushes logs to Loki via the gateway with `X-Scope-OrgID: homelab`.

```alloy
discovery.kubernetes "pods" {
  role = "pod"
}

loki.source.kubernetes "pods" {
  targets = discovery.kubernetes.pods.targets
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki-gateway.monitoring-system.svc.cluster.local/loki/api/v1 push"
    headers = { "X-Scope-OrgID" = "homelab" }
  }
}
```

## References

- [Grafana Alloy documentation](https://grafana.com/docs/alloy/latest/)
- [Alloy Helm chart](https://artifacthub.io/packages/helm/grafana/alloy)
- [Promtail deprecation notice](https://grafana.com/docs/loki/latest/send-data/promtail/)
- [Alloy vs Promtail migration guide](https://grafana.com/docs/alloy/latest/collect/promtail-to-alloy/)
