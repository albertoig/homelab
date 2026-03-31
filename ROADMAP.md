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
- [x] ADR docs structure
- [x] Automation scripts
    - [x] Encrypt secrets (SOPS)
    - [x] Decrypt secrets (SOPS)
    - [x] Install Helmfiles script
    - [x] Destroy Helmfile script
    - [x] Add beautiful colors to scripts
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
---

## 🚧 In Progress
- [ ] Automate kubeconfig setup with helm-diff and helm-secrets plugins for new developer onboarding
- [ ] ADR integration into merge request workflow
- [ ] Grafana Dashboards
    - [x] Longhorn
    - [x] Loki
    - [ ] Metallb
    - [ ] Traefik
    - [ ] Authentik
    - [ ] Argocd
    - [ ] Tempo
    - [ ] External-dns
    - [ ] Grafana
    - [ ] Cert-Manager
- [ ] Review meta monitoring https://grafana.com/docs/loki/latest/operations/meta-monitoring/
- [ ] Migrate Loki (longhorn) to distributed from single binary
- [ ] Adjust values and secrets templates

---

## 📋 Planned
- [ ] Investigate Grafana Beyla eBPF auto-instrumentation for services without native tracing (Authentik, Longhorn, MetalLB, Cert-Manager, External-DNS)
- [ ] Backup solution
- [ ] Disaster recovery plan
- [ ] Documentation improvements
- [ ] Helmfile configuration
- [ ] Centralize scripting to run everything with one command
- [ ] Create Grafana dashboards for Authentik and ArgoCD
- [ ] Authentik Auth
    - [ ] Grafana
- [ ] Badges on Readme
- [ ] Testing scrips
- [ ] String with URL of the services
---

## 📝 Notes
No additional notes.
