# 🗺️ Roadmap

## Overview

This roadmap tracks the progress of the homelab setup,
from initial infrastructure provisioning to a fully automated
GitOps-driven environment.

---

## ✅ Completed
- [x] Initial K3s cluster setup with Ansible
- [x] SSH hardening
- [x] Semantic Release configuration
- [x] ADR docs structure
- [x] SOPS secrets management (templates, init script, per-chart architecture)
- [x] Automation scripts (install, destroy, encrypt/decrypt secrets, check requirements, check Kubernetes, check secrets)
- [x] Monitoring stack (Prometheus + Grafana + Loki + Tempo + Pyroscope) with cross-signal correlation
- [x] Alloy replacing Promtail — OTel log collection and eBPF profiling (ADR-002)
- [x] OTel tracing for Traefik, ArgoCD, Grafana
- [x] Prometheus service monitors for all services
- [x] Grafana dashboards (Longhorn, Loki, MetalLB, Traefik, External-DNS, Kubernetes, CoreDNS, Authentik, ArgoCD)
- [x] Per-environment config system (ADR-005)
- [x] Authentik SSO for Grafana and ArgoCD
- [x] Authentication layer fixes — zero manual steps after install
- [x] Documentation (SCRIPTS.md, SECRETS.md, CONFIG.md, INSTALL.md, FORKING.md, VERSIONING.md)
- [x] Velero — Kubernetes backup and restore with Cloudflare R2

---

## 🚧 In Progress
- [ ] Authentik Auth
    - [ ] Longhorn
    - [ ] Prometheus
    - [x] Review best practices SSO

---

## 📋 Planned

### P2 — SSO Security Hardening
- [ ] Implement `!File` + volume mount for Authentik blueprint secrets — credentials are currently injected as env vars, visible in `kubectl describe pod`; switch to volume-mounted files via `!File` as planned in `docs/decisions/blueprints-secret-handling.md`
- [ ] Disable ArgoCD local authentication completely — ensure no local accounts via `configs.cm.accounts.*` (bypass Authentik); document restriction in `CONTRIBUTING.md`
- [ ] Add group-based access policy bindings to Authentik applications — currently `policy_engine_mode: any` with no bindings; scope access to `Grafana Admins` / `ArgoCD Admins` groups
- [ ] Add Traefik security headers middleware — `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Content-Security-Policy` applied to all ingresses
- [ ] Fix `issuer_mode` on Grafana OAuth2 provider — should use `per_provider` to match ArgoCD
- [ ] Add MFA stage to Authentik authorization flows — add TOTP or WebAuthn stage to protect admin tools
- [ ] Review MetalLB self-signed certificate for metrics — evaluate cert-manager replacement vs. current `insecureSkipVerify: true`

### P2 — Reliability and completeness
- [ ] Self-hosted GitHub Actions runner — deploy `actions-runner-controller` to re-enable helmfile lint against real environments without exposing the SOPS key to GitHub
- [ ] Disaster recovery plan — document how to rebuild the cluster and restore data from scratch
- [ ] Velero manual backup test — trigger a backup, verify it completes without errors, restore a namespace and confirm data integrity; fix the 10 partial errors seen in initial run
- [ ] Add preflight validation for empty `root_dns` — helmfile silently generates ingresses with empty hostnames if unset
- [ ] Remove empty `dev.yaml` and `prod.yaml` environment stubs — referenced in release files but contain no content
- [x] Move imperative remediation hooks out of helmfile — replaced by `scripts/infra/doctor.sh` (`mise run doctor`), diagnose-only by default with confirmed fixes via `--fix`
- [ ] Investigate root causes the doctor only treats — MetalLB/Grafana service finalizer ordering on delete, and the Longhorn volume mount race that leaves Loki/Tempo pods stuck in Pending after node restarts
- [ ] Re-enable helmfile lint in CI via a `ci` environment — a third environment with no `secrets:` entries and dummy SSO values would let `helmfile lint` run on GitHub today, without waiting for the self-hosted runner (which remains the path for linting against real environments)
- [ ] Add `kubeconform` validation of rendered manifests in CI — `helm lint` does not catch Kubernetes schema errors; validate `helmfile template` output
- [ ] Add `shellcheck` to pre-commit — shellspec tests behavior but does not catch quoting/word-splitting bugs across the ~1,800 lines of bash in `scripts/`
- [ ] Add non-interactive mode to `install.sh` — `gum confirm` and spinners block any future CI/cron/self-hosted-runner usage; add a `--yes` flag before retrofitting becomes painful
- [ ] Extend shellspec coverage to the largest scripts — `secrets/init.sh` (363 lines), `apps/setup-openbao.sh` (263), `helm/install.sh` (206) are untested while the covered libs total ~170 lines

### P3 — Platform (build on top of this infra)
- [x] OpenBao — runtime secret manager with External Secrets Operator to bridge OpenBao → Kubernetes Secrets
  - Post-deploy setup is automated and idempotent via `mise run openbao:setup` (init, unseal, KV v2, ESO policy + token, ClusterSecretStore); the unseal keys and root token are shown once to save
- [ ] OpenBao hardening — document where unseal keys and the root token must be stored, revoke the root token after the ESO token is created, evaluate auto-unseal (static or transit) so a node reboot doesn't leave dependent workloads down, and replace the static ESO token with Kubernetes auth (no token to expire or leak)
- [x] Secrets end-state ADR — documented in [ADR-007](docs/decisions/helmfile/ADR-007-openbao-eso-runtime-secrets.md): the boundary between SOPS (bootstrap, render-time) and OpenBao + ESO (runtime, incl. downstream repos), and the secret-delivery choice (ESO vs the injector/CSI) with trade-offs. Status `Proposed` → `Accepted` on merge
- [ ] Evaluate etcd secrets encryption-at-rest — because ESO materializes OpenBao values into base64 Kubernetes Secrets, they sit unencrypted in etcd; enabling k3s `--secrets-encryption` closes the blast-radius gap the injector's in-memory model would have avoided
- [ ] Add rotated-secret propagation — ESO refreshes the Secret on its sync interval, but env-var consumers don't pick up the change without a restart (mounted files update in place); add Stakater Reloader or standardise on file mounts so rotated/updated secrets reach running pods
- [ ] CloudNativePG — PostgreSQL operator; replaces embedded per-chart Postgres with a managed, reusable database layer
- [ ] Kyverno — admission policy enforcement; baseline: require resource limits, block root containers, enforce label schemas
- [ ] Zot or Harbor — container registry for CI-built images

### P4 — Quality of life
- [ ] Grafana Dashboards
    - [ ] Tempo
    - [ ] Cert-Manager
- [ ] ADR integration into merge request workflow — automate the ADR requirement check on PRs
- [ ] Track helm-secrets plugin version — `docs/INSTALL.md` pins v4.7.4 with a direct URL, not tracked by Renovate
- [ ] Remove scripts hard-limit to `dev`/`prod` — `helm/install.sh`, `helm/destroy.sh`, `secrets/init.sh` (via `lib/env.sh`) reject any other environment name
- [ ] Centralize environment → kube-context resolution — the `kubeContext` per environment is defined in `helmfile.yaml.gotmpl` (`homelab-dev`, `homelab-prod`) but `scripts/lib/env.sh` hardcodes the env list and `doctor.sh`/`preflight.sh` re-derive the `homelab-` prefix independently; add a small lib helper (or script) that reads the environments and their contexts from the helmfile (e.g. via `yq`) so scripts stop duplicating the mapping — pairs with removing the dev/prod hard-limit above
- [ ] Fix lock file numbering — `005-ingresses.helmfile.yaml.gotmpl` references `004-ingresses.helmfile.lock` (cosmetic inconsistency)
- [ ] Simplify config with scripts — `root_dns` is set in `config.yaml` but DNS-related values are also prompted separately in `secrets-init`; reduce duplication
- [x] Refresh `docs/SCRIPTS.md` — rewritten for the domain-based `scripts/` layout (lib/infra/helm/secrets/apps), the current mise tasks, OpenBao setup, and the test suite
- [ ] Extract secrets template parsing from `init.sh`/`lib/secrets.sh` into a small Python CLI — the hand-rolled YAML parser in bash (`find_colon`, `yaml_value`, `build_path`) should become a pytest-tested `scripts/secrets/template.py` that emits the field list, leaving the gum prompting loop in bash
- [ ] Split `004-core-apps` by architecture layer — it currently mixes storage, networking, monitoring, logging, identity, and GitOps in one stage; splitting (e.g. storage/network, observability, identity/gitops) would match the layers described in the README and shrink blast radius per change
- [x] Clarify ArgoCD/OpenBao role in README — reworded the overview: ArgoCD and OpenBao are platform services for downstream application repos, they do not manage this repo's own releases (deployed by helmfile)

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
