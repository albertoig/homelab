# 🗺️ Roadmap

## Overview

This roadmap tracks the progress of the homelab setup,
from initial infrastructure provisioning to a fully automated
GitOps-driven environment.


---

## ✅ Completed
- [x] Initial K3s cluster setup with Ansible
- [x] Semantic Release Initial Configuration
- [x] OTel Tracing for Traefik, ArgoCD, Grafana
- [x] SSH hardening
- [x] SOPS secrets management structure
    - [x] Secrets template
    - [x] Script to initialize secrets
    - [x] Per-chart secrets architecture
    - [x] Secrets reference doc (docs/SECRETS.md)
- [x] Monitoring stack (Prometheus + Grafana + Tempo + Pyroscope)
    - [x] Cross-signal correlation (Loki ↔ Tempo ↔ Pyroscope)
- [x] Alloy replacing Promtail (ADR-002)
    - [x] OpenTelemetry log collection via Alloy
    - [x] eBPF profiling via Alloy → Pyroscope
- [x] ADR docs structure
- [x] Automation scripts
    - [x] Encrypt secrets (SOPS)
    - [x] Decrypt secrets (SOPS)
    - [x] Install Helmfiles script
    - [x] Destroy Helmfile script
    - [x] Add beautiful colors to scripts
    - [x] Check requirements script
    - [x] Check Kubernetes script
- [x] Prometheus (Service Monitor)
    - [x] Longhorn
    - [x] Metallb
    - [x] Traefik
    - [x] Authentik
    - [x] Argocd
    - [x] Loki
    - [x] Tempo
    - [x] External-dns
    - [x] Grafana
    - [x] Cert-Manager
- [x] Grafana Dashboards
    - [x] Longhorn
    - [x] Loki
    - [x] Metallb
    - [x] Traefik
    - [x] External-dns
    - [x] Grafana (node-exporter, kubernetes-cluster, kubernetes-pods, coredns)
- [x] Per-environment config system (ADR-005)
    - [x] Config template with descriptions and defaults
    - [x] Per-environment config.yaml (general, metallb, grafana, prometheus, alertmanager)
    - [x] Common values read config via readFile/fromYaml
    - [x] Config reference doc (docs/CONFIG.md)
    - [x] Consolidated per-env values into common values
- [x] Documentation
    - [x] Scripts doc (docs/SCRIPTS.md)
    - [x] Secrets reference doc (docs/SECRETS.md)
    - [x] Config reference doc (docs/CONFIG.md)
    - [x] Installation guide (docs/INSTALL.md)
    - [x] ADR-005 config system decision record
- [x] Authentik SSO Auth
    - [x] Grafana
    - [ ] ARGO CD
---
carlos enrique sone morales
enrique sone
## 🚧 In Progress
- [ ] Authentik Auth
    - [ ] LongHorn
    - [ ] Prometheus
    - [ ] Review best practices SSO

---

## 📋 Planned
- [ ] Automate kubeconfig setup with helm-diff and helm-secrets plugins for new developer onboarding
- [ ] ADR integration into merge request workflow
- [ ] Grafana Dashboards
    - [ ] Authentik
    - [ ] Argocd
    - [ ] Tempo
    - [ ] Cert-Manager
- [ ] Review meta monitoring https://grafana.com/docs/loki/latest/operations/meta-monitoring/
- [ ] Migrate Loki (longhorn) to distributed from single binary
- [ ] Investigate Grafana Beyla eBPF auto-instrumentation for services without native tracing (Authentik, Longhorn, MetalLB, Cert-Manager, External-DNS)
- [ ] Backup solution
- [ ] Disaster recovery plan
- [ ] Helmfile configuration
- [ ] Badges on Readme
- [ ] Testing scripts
- [ ] Study to migrate HTTP URL in helm repositories to the new format
- [ ] Adjust scripts to number of environments in helmfile folder
- [ ] Remove duplicates secrets
- [ ] Make easier configs with scripts (DNS reused in secrets and normal config) 
- [ ] Look for a centralized dashboard system that add all the services that are exposed through load balancer.
---

## 📝 Notes
No additional notes.
