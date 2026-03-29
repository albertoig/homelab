# Architecture Decision Records (ADR)

Architecture decisions for the homelab project. Each decision is documented with context, alternatives considered, and consequences. See [ADR-TEMPLATE.md](ADR-TEMPLATE.md) for the template used.

## Helmfile

Decisions related to Helm charts, helmfile configuration, and Kubernetes service deployments.

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-001](helmfile/ADR-001-loki-grafana-community-migration.md) | Migrate Loki to grafana-community chart | 2026-03-29 | Accepted |
| [ADR-002](helmfile/ADR-002-alloy-replacing-promtail.md) | Replace Promtail with Alloy for log collection | 2026-03-29 | Accepted |

## Ansible

Decisions related to Ansible playbooks, bare metal provisioning, and K3s cluster configuration.

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-003](ansible/ADR-003-sysctl-tuning.md) | Add sysctl tuning for K3s inotify limits | 2026-03-29 | Accepted |
