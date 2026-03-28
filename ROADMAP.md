# 🗺️ Roadmap

## Overview

This roadmap tracks the progress of the homelab setup,
from initial infrastructure provisioning to a fully automated
GitOps-driven environment.


---

## ✅ Completed
- [x] Initial K3s cluster setup with Ansible
- [x] Semantic Release Initial Configuration
- [x] SSH hardening
- [x] SOPS secrets management
- [x] Monitoring stack (Prometheus + Grafana)
- [x] Prometheus (Service Monitor)
    - [x] Longhorn
    - [x] Metallb
    - [x] Traefik
    - [x] Authentik
    - [x] Argocd
    - [x] Loki
    - [x] Tempo
    - [x] External-dns

---

## 🚧 In Progress
- [ ] Generate kube config and copy it to the local machine pre configured. (also the  pluging diff and secrets)
- [ ] Prometheus (Service Monitor)
    - [ ] Grafana
    - [ ] Cert-Manager


---

## 📋 Planned
- [ ] Backup solution
- [ ] Disaster recovery plan
- [ ] Documentation improvements
- [ ]Centralize secrets and configs in the root directory
- [ ] Helmfile configuration
- [ ] Centralize scripting to run everything with one command.
- [ ] Create Grafana dashboards for Authentik and ArgoCD

---

## 📝 Notes
No aditional notes.
