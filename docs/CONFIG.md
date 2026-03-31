# Configuration Reference

Complete reference for the homelab configuration system. Configuration values are non-secret user settings stored in `helmfile/environments/<env>/config.yaml`.

## How the config system works

```
helmfile/config.template.yaml   (template with defaults and descriptions)
        │
        ▼  copy to per-environment
helmfile/environments/<env>/config.yaml   (user-editable, committed)
        │
        ▼  read by common values gotmpl files via readFile/fromYaml
Helm values (rendered per-chart)
```

Each environment has its own `config.yaml` that controls non-secret settings like domain names, IP pools, storage sizes, and replica counts. The config template (`helmfile/config.template.yaml`) documents all available options with defaults and is the source of truth for what can be configured.

The config system mirrors the secrets system but for non-sensitive values:
- **Secrets** (`helmfile/secret-templates/`): passwords, API keys, tokens — encrypted with SOPS
- **Config** (`helmfile/config.template.yaml`): domain names, IP pools, storage — plaintext, committed

### How values are loaded

Common values files (`helmfile/common/values/*.yaml.gotmpl`) read the environment config at the top of each file:

```yaml
{{- $cfg := readFile (printf "../../environments/%s/config.yaml" .Environment.Name) | fromYaml -}}
```

Then reference config values directly:

```yaml
persistence:
  size: {{ $cfg.grafana.storage }}
```

Per-environment values files (`helmfile/environments/<env>/values/`) are kept minimal — only for true per-environment overrides (e.g., disabling ingress in dev).

---

## Config structure

```yaml
general:          # Reusable values referenced across multiple charts
metallb:          # MetalLB load balancer settings
grafana:          # Grafana monitoring dashboards
prometheus:       # Prometheus metrics collection
alertmanager:     # Alertmanager alert routing
```

---

## General

Shared values used by multiple charts. The `root_dns` is the base domain from which all service hostnames are derived.

| Key | Description | Default | Example |
|-----|-------------|---------|---------|
| `general.root_dns` | Root DNS domain. All service hostnames are derived from this. | `""` | `iglesias.cloud` |
| `general.dns.provider` | DNS provider used by external-dns and cert-manager. | `cloudflare` | `cloudflare` |

**Hostname derivation** — `root_dns` is used to construct service hostnames:

| Service | Hostname pattern | Example |
|---------|-----------------|---------|
| Grafana | `grafana.internal.{root_dns}` | `grafana.internal.iglesias.cloud` |
| ArgoCD | `argocd.internal.{root_dns}` | `argocd.internal.iglesias.cloud` |
| Longhorn | `longhorn.internal.{root_dns}` | `longhorn.internal.iglesias.cloud` |
| Authentik | `auth.{root_dns}` | `auth.iglesias.cloud` |

---

## MetalLB

Load balancer IP address pools for bare-metal Kubernetes.

| Key | Description | Default | Example |
|-----|-------------|---------|---------|
| `metallb.ipPool` | IP address range for MetalLB LoadBalancer services. Format: `start-end`. | `""` | `10.0.0.161-10.0.0.170` |

**Used by:** `helmfile/common/values/metallb-config.yaml.gotmpl`

---

## Grafana

Monitoring dashboards.

| Key | Description | Default | Example |
|-----|-------------|---------|---------|
| `grafana.storage` | Persistent volume size for Grafana data. | `10Gi` | `2Gi` |
| `grafana.port` | Service port. Use `30080` if Traefik occupies port 80. | `30080` | `80` |

**Used by:** `helmfile/common/values/grafana.yaml.gotmpl`

---

## Prometheus

Metrics collection and alerting.

| Key | Description | Default | Example |
|-----|-------------|---------|---------|
| `prometheus.replicas` | Number of Prometheus replicas. | `1` | `2` |
| `prometheus.retention` | Metrics retention period. | `15d` | `30d` |
| `prometheus.storage` | Persistent volume size for Prometheus data. | `10Gi` | `20Gi` |

**Used by:** `helmfile/common/values/prometheus-stack.yaml.gotmpl`

---

## Alertmanager

Alert routing and notification.

| Key | Description | Default | Example |
|-----|-------------|---------|---------|
| `alertmanager.replicas` | Number of Alertmanager replicas. | `1` | `2` |
| `alertmanager.storage` | Persistent volume size for Alertmanager data. | `1Gi` | `2Gi` |

**Used by:** `helmfile/common/values/prometheus-stack.yaml.gotmpl`

---

## Environment examples

### Production

```yaml
# helmfile/environments/prod/config.yaml
general:
  root_dns: iglesias.cloud
  dns:
    provider: cloudflare

metallb:
  ipPool: 10.0.0.161-10.0.0.170

grafana:
  storage: 10Gi
  port: 30080

prometheus:
  replicas: 2
  retention: 30d
  storage: 20Gi

alertmanager:
  replicas: 2
  storage: 2Gi
```

### Development

```yaml
# helmfile/environments/dev/config.yaml
general:
  root_dns: dev.iglesias.cloud
  dns:
    provider: cloudflare

metallb:
  ipPool: 10.0.0.150-10.0.0.160

grafana:
  storage: 2Gi
  port: 80

prometheus:
  replicas: 1
  retention: 7d
  storage: 10Gi

alertmanager:
  replicas: 1
  storage: 1Gi
```

---

## Adding a new config value

1. Add the field to `helmfile/config.template.yaml` with a description and default.
2. Add the value to each environment's `config.yaml`.
3. Reference it in the appropriate common values gotmpl file using `$cfg.<chart>.<key>`.

---

## Related

- **Secrets:** [SECRETS.md](./SECRETS.md) — encrypted values (passwords, API keys)
- **Scripts:** [SCRIPTS.md](./SCRIPTS.md) — automation scripts
- **ADR:** [decisions/helmfile/ADR-005-config-system.md](./decisions/helmfile/ADR-005-config-system.md) — why the config system was created
