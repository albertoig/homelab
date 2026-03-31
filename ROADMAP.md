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
- [x] Monitoring stack (Prometheus + Grafana + Tempo + Pyroscope)
    - [x] Cross-signal correlation (Loki ↔ Tempo ↔ Pyroscope)
- [x] ADR docs structure
- [x] Automation scripts
    - [x] Encrypt secrets(SOPS)
    - [x] Decrypt secrets(SOPS)
    - [x] Install Helmmfiles script
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
- [ ] Grafana Dashboards
    - [x] Longhorn
    - [ ] Metallb
    - [ ] Traefik
    - [ ] Authentik
    - [ ] Argocd
    - [x] Loki
    - [ ] Tempo
    - [ ] External-dns
    - [ ] Grafana
    - [ ] Cert-Manager
---

## 🚧 In Progress
- [ ] Generate kube config and copy it to the local machine pre configured. (also the  pluging diff and secrets)
- [ ] ADR docs structure for MR request
- [ ] Grafana Dashboards
    - [ ] Metallb
    - [ ] Traefik
    - [ ] Authentik
    - [ ] Argocd
    - [ ] Tempo
    - [ ] External-dns
    - [ ] Grafana
    - [ ] Cert-Manager
- [ ] Review meta monitoring https://grafana.com/docs/loki/latest/operations/meta-monitoring/
- [ ] Migrate Loki(longhorn) to distributed from single binary.


---

## 📋 Planned
- [ ] Investigate Grafana Beyla eBPF auto-instrumentation for services without native tracing (Authentik, Longhorn, MetalLB, Cert-Manager, External-DNS)
- [ ] Backup solution
- [ ] Disaster recovery plan
- [ ] Documentation improvements
- [ ] Centralize secrets and configs in the root directory
- [ ] Helmfile configuration
- [ ] Centralize scripting to run everything with one command.
- [ ] Create Grafana dashboards for Authentik and ArgoCD
- [ ] Authentik Auth
    - [ ] Grafana
- [ ] Badges on Readme
---

## 📝 Notes
No aditional notes.
