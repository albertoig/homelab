# Architecture Decision Records (ADR)

Architecture decisions for the homelab project. Each decision is documented with context, alternatives considered, and consequences. See [ADR-TEMPLATE.md](ADR-TEMPLATE.md) for the template used.

## Helmfile

Decisions related to Helm charts, helmfile configuration, and Kubernetes service deployments.

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-001](helmfile/ADR-001-loki-grafana-community-migration.md) | Migrate Loki to grafana-community chart | 2026-03-29 | Accepted |
| [ADR-002](helmfile/ADR-002-alloy-replacing-promtail.md) | Replace Promtail with Alloy for log collection | 2026-03-29 | Accepted |
| [ADR-003](helmfile/ADR-003-tracing-via-alloy.md) | Route application traces through Alloy instead of Tempo | 2026-03-30 | Accepted |
| [ADR-004](helmfile/ADR-004-ebpf-kernel-symbol-access.md) | Enable eBPF kernel symbol access for Pyroscope profiling | 2026-03-30 | Accepted |
| [ADR-005](helmfile/ADR-005-config-system.md) | Per-environment config system for user-configurable settings | 2026-03-31 | Accepted |

## Ansible

Decisions related to Ansible playbooks, bare metal provisioning, and K3s cluster configuration.

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-001](ansible/ADR-001-sysctl-tuning.md) | Add sysctl tuning for K3s inotify limits | 2026-03-29 | Accepted |

## Project

Decisions related to project structure, distribution model, and contribution workflow.

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-001](project/ADR-001-fork-based-user-config.md) | Fork-based model for user configs and secrets | 2026-03-31 | Proposed |
