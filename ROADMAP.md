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
    - [x] ArgoCD
- [x] Authentication layer fixes (zero manual steps after install)
    - [x] Fix hardcoded `iglesias.cloud` domain in blueprint redirect URIs and launch URLs
    - [x] Add admin user to Grafana Admins and ArgoCD Admins groups in blueprint
    - [x] Add ArgoCD RBAC policy to map Authentik groups to ArgoCD roles
    - [x] Remove dead `genSelfSignedCert` from `authentik-blueprints/values.yaml.gotmpl`
    - [x] Remove dead `grafana.adminPassword` from secret template and Grafana values
    - [x] Document emergency access for Grafana (`/login?disableAutoLogin`) and ArgoCD

---

## 🚧 In Progress
- [ ] Authentik Auth
    - [ ] Longhorn
    - [ ] Prometheus
    - [ ] Review best practices SSO

---

## 📋 Planned

### P1 — Fix now
- [x] Fix ClusterIssuer hardcoded to `letsencrypt-prod` — dev environment requests certs against a non-existent issuer (`charts/cert-manager-config/values.yaml:13`)
- [x] Delete plaintext `prod/secrets/*.secrets.yaml` — decrypted files must not persist on disk after encryption
- [ ] Remove duplicate Cloudflare email in `cert-manager-config.template.yaml` — `secret.email` and `clusterIssuer.cloudflare.email` are the same value, prompted twice during `secrets-init`
- [ ] Wire `alertmanagerSlackWebhook` into Alertmanager config or remove it from the secret template — currently collected and encrypted but never used

### P2 — Reliability and completeness
- [ ] Velero — Kubernetes backup and restore; use Cloudflare R2 or Backblaze B2 as the S3-compatible backend (offsite, no extra services on-cluster)
- [ ] Disaster recovery plan — document how to rebuild the cluster and restore data from scratch
- [ ] Add preflight validation for empty `root_dns` — helmfile silently generates ingresses with empty hostnames if `general.root_dns` is unset in config.yaml
- [ ] Remove empty `dev.yaml` and `prod.yaml` environment stubs — referenced in release files but contain no content (`helmfile/environments/dev/dev.yaml`, `helmfile/environments/prod/prod.yaml`)

### P3 — Platform (build on top of this infra)
- [ ] OpenBao — runtime secret manager; deploy with External Secrets Operator to bridge OpenBao → Kubernetes Secrets automatically
- [ ] CloudNativePG — PostgreSQL operator for Kubernetes; replaces embedded per-chart Postgres with a managed, reusable database layer for all applications
- [ ] Kyverno — policy enforcement at the admission layer; baseline policies: require resource limits, block root containers, enforce label schemas
- [ ] Zot or Harbor — container registry for storing images built by CI; Zot is lightweight and OCI-native, Harbor adds scanning and access control

### P4 — Quality of life
- [ ] Grafana Dashboards
    - [ ] Authentik
    - [ ] ArgoCD
    - [ ] Tempo
    - [ ] Cert-Manager
- [ ] ADR integration into merge request workflow — automate the ADR requirement check on PRs
- [ ] Track helm-secrets plugin version — `docs/INSTALL.md` pins v4.7.4 with a direct URL, not tracked by Renovate
- [ ] Remove scripts hard-limit to `dev`/`prod` — `install-helmfiles.sh`, `destroy-helmfiles.sh`, `init-secrets.sh` reject any other environment name
- [ ] Fix lock file numbering — `005-ingresses.helmfile.yaml.gotmpl` references `004-ingresses.helmfile.lock` (cosmetic inconsistency)
- [ ] Simplify config with scripts — `root_dns` is set in `config.yaml` but DNS-related values are also prompted separately in `secrets-init`; reduce duplication

### P5 — Nice to have
- [ ] Grafana Dashboards
    - [ ] Review meta monitoring (Loki self-monitoring)
- [ ] Investigate Grafana Beyla eBPF auto-instrumentation for services without native tracing (Authentik, Longhorn, MetalLB, Cert-Manager, External-DNS)
- [ ] Look for a centralized service dashboard (e.g. Heimdall) for all LoadBalancer-exposed services
- [ ] Study migration of HTTP helm repository URLs to OCI format
- [ ] Migrate Loki to distributed mode — only relevant at scale, low priority for a homelab

---

## 📝 Notes
No additional notes.
