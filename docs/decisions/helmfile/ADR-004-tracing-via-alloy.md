# ADR-004: Route Application Traces Through Alloy Instead of Directly to Tempo

- **Date**: 2026-03-30
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: monitoring

## Context

The cluster has an observability stack consisting of Prometheus (metrics), Loki (logs), Tempo (traces), and Pyroscope (profiling). Alloy was deployed as the unified OpenTelemetry collector (see [ADR-002](ADR-002-alloy-replacing-promtail.md)) to handle log collection, eBPF profiling, and trace forwarding.

Initially, Traefik was configured to send traces directly to Tempo (`http://tempo.prometheus.svc.cluster.local:4318/v1/traces`). When adding tracing to additional services (ArgoCD, Grafana), the question arose: should traces go directly to Tempo, or through Alloy?

The existing Alloy configuration already exposes OTLP receiver ports (4317 gRPC, 4318 HTTP) and forwards traces to Tempo via `otelcol.exporter.otlp`:

```alloy
otelcol.receiver.otlp "default" {
  http {
    endpoint = "0.0.0.0:4318"
  }
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo.prometheus.svc.cluster.local:4317"
    tls {
      insecure = true
    }
  }
}
```

## Decision

Route all application traces through Alloy (ports 4317/4318) instead of sending them directly to Tempo.

## Alternatives Considered

### Option A: Send Traces Directly to Tempo
- **Description**: Each service sends traces directly to Tempo's OTLP endpoints.
- **Pros**:
  - One fewer hop; slightly lower latency.
  - Simpler topology; fewer moving parts.
- **Cons**:
  - Each service must know Tempo's service address directly.
  - Adding a new trace processor (sampling, filtering, enrichment) requires updating every service's configuration.
  - Inconsistent with the Alloy-first telemetry architecture established for logs and profiles.
  - Bypasses Alloy's OTel pipeline; no central point for trace-level processing rules.
  - If Tempo's service address changes, all services must be updated.

### Option B: Route Through Alloy (Selected)
- **Description**: All services send traces to Alloy's OTLP endpoints. Alloy forwards to Tempo.
- **Pros**:
  - Centralizes all telemetry collection through a single collector.
  - Consistent with how Alloy already handles logs and profiles.
  - Enables future trace processing at the collector level (sampling, attribute enrichment, tail-based sampling, filtering) without touching service configs.
  - Services only need to know Alloy's address, not Tempo's.
  - Follows the OpenTelemetry Collector pattern: instrument → collect → export.
- **Cons**:
  - One additional network hop (Alloy → Tempo).
  - Alloy becomes a dependency for traces; if Alloy is down, traces are dropped (though logs already have this same dependency).

## Consequences

### Positive
- Unified telemetry pipeline: logs, profiles, and traces all flow through Alloy.
- Adding future trace processors (e.g., tail-based sampling, attribute normalization) requires only Alloy config changes.
- Service configurations are decoupled from the Tempo backend; Tempo can be replaced or moved without updating any service.
- Consistent with the Grafana Alloy architecture documented in ADR-002.

### Negative
- One additional hop introduces marginal latency (negligible for a homelab).
- Alloy is now a single point of failure for all telemetry signals, not just logs.

### Risks
- **Risk**: Alloy becomes overloaded if trace volume is high.
  - **Mitigation**: Set sampler configuration on applications (ArgoCD uses `parentbased_traceidratio` at 0.1). Monitor Alloy resource usage via its ServiceMonitor. Adjust resource limits if needed.

## Configuration

All services point to Alloy's cluster-internal address:

| Service | Endpoint | Protocol |
|---------|----------|----------|
| Traefik | `http://alloy.prometheus.svc.cluster.local:4318/v1/traces` | HTTP |
| ArgoCD | `http://alloy.prometheus.svc.cluster.local:4317` | gRPC |
| Grafana | `alloy.prometheus.svc.cluster.local:4317` | gRPC |

## References

- [ADR-002: Replace Promtail with Alloy for Log Collection](ADR-002-alloy-replacing-promtail.md)
- [OpenTelemetry Collector pattern](https://opentelemetry.io/docs/collector/)
- [Grafana Alloy OTLP receiver](https://grafana.com/docs/alloy/latest/reference/components/otelcol/otelcol.receiver.otlp/)
- [ArgoCD OTLP tracing](https://argo-cd.readthedocs.io/en/stable/operator-manual/tracing/)
- [Grafana tracing configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/configure-tracing/)
