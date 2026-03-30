# 🗺️ Roadmap

## Overview

This roadmap tracks the progress of the homelab setup,
from initial infrastructure provisioning to a fully automated
GitOps-driven environment.


---

## ✅ Completed
- [x] Initial K3s cluster setup with Ansible
- [x] Semantic Release Initial Configuration
- [x] Cross-signal correlation (Loki ↔ Tempo ↔ Pyroscope)
- [x] SSH hardening
- [x] SOPS secrets management
- [x] Monitoring stack (Prometheus + Grafana)
- [x] ADR docs structure
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
- [x] ADR docs structure for MR request
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
