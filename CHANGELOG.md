# 1.0.0-beta.1 (2026-05-28)


* feat(monitoring)!: migrate Loki to v9, add Alloy collector, and tune sysctl ([ba83486](https://github.com/albertoig/homelab/commit/ba834866bcd533d92dd26139ba2d98f663783e59))
* refactor(namespaces)!: rename service namespaces to follow system naming convention ([025b41e](https://github.com/albertoig/homelab/commit/025b41ef5851bcde2813b1b1cf07f8db48cc94a6))


### Bug Fixes

* **cert-manager-config:** derive ClusterIssuer name from environment ([3fca3d7](https://github.com/albertoig/homelab/commit/3fca3d7a2a1dd531e3a9f3934f4ceda1dff67abf))
* **charts:** assign admin user to Grafana and ArgoCD groups in authentik blueprint ([66c8ad5](https://github.com/albertoig/homelab/commit/66c8ad52f8f21fa0b51bb63203f5352dcd59d4a1))
* **charts:** replace hardcoded domain with root_dns in authentik blueprint redirect URIs ([35ba9b0](https://github.com/albertoig/homelab/commit/35ba9b061ca786f8b044eb17b7434b7d71272182))
* **ci:** disable helmfile-lint until self-hosted runner is available ([b1536a9](https://github.com/albertoig/homelab/commit/b1536a9e2b9b9e69250bc709673cce1c4c1f7287))
* **ci:** update helmkit action to v1.1.0 and add --skip-deps to lint ([fe611a5](https://github.com/albertoig/homelab/commit/fe611a507ede9e145ac4f6593bde81f3330cb729))
* configure ansible-lint to skip formatting rules ([bd5ca62](https://github.com/albertoig/homelab/commit/bd5ca620ce7a4e2bf5a65a4604beae1e7a2c6ff0))
* **github:** use lint values with void secrets ([f0434c1](https://github.com/albertoig/homelab/commit/f0434c156470b75c01ce8a1bf2aec38f85350bce))
* **github:** use shared concurrency group to prevent deadlock ([8817c3f](https://github.com/albertoig/homelab/commit/8817c3fabbe3f14bc4106170cdcf18773f511164))
* **github:** use shared concurrency group to prevent deadlock ([ff46ea0](https://github.com/albertoig/homelab/commit/ff46ea048b09190777ac68f0fd926f9e4c9a86fe))
* **github:** use shared concurrency group to prevent deadlock ([5b84775](https://github.com/albertoig/homelab/commit/5b84775d04bbb83f2ce1db06e78ac175053a5bec))
* **grafana:** add correctly the admin password for grafana ([520340b](https://github.com/albertoig/homelab/commit/520340b47139ba903b62d65a7d3068aac47719df))
* **helmfile:** add ArgoCD RBAC policy to map ArgoCD Admins group to admin role ([970caa5](https://github.com/albertoig/homelab/commit/970caa51832f6d23ac495c28ad23c542f7bdc27c))
* **monitoring:** change storage from gp2 to local-path for K3s compatibility ([ec93f86](https://github.com/albertoig/homelab/commit/ec93f865283229803cfa2c11cb1cc11e47e5c572))
* **scripts:** delete plaintext secrets after encryption ([448c334](https://github.com/albertoig/homelab/commit/448c3348ff59d4230e9f563391b9a0bd9031761c))
* **secrets:** remove duplicate cloudflare email and unused alertmanager webhook ([bf85952](https://github.com/albertoig/homelab/commit/bf85952a78a6bf99d55762dedae7f87f34b97f54))


### chore

* remove postgres and redis dependencies ([8d20c14](https://github.com/albertoig/homelab/commit/8d20c14a2e3d06fc9d6768159f86d3b9416c5c65))


### Features

* add ArgoCD GitOps continuous delivery platform ([cffeffd](https://github.com/albertoig/homelab/commit/cffeffd7dcbba4ab167443d6e0f0badf415edbe7))
* add external-dns monitoring and Grafana dashboard ([95f3e57](https://github.com/albertoig/homelab/commit/95f3e57563e23bc7ad40e8a7306656e236b183e1))
* **authentik:** add Authentik identity provider to homelab ([9be209c](https://github.com/albertoig/homelab/commit/9be209cd7eef2d4e69b2e1432067f61df05bd37f))
* **authentik:** add bootstrap token and admin configuration ([7cb5529](https://github.com/albertoig/homelab/commit/7cb55296d91a8c03feb777bd1b522da6f0bf1cec))
* **cert-manager:** add cert-manager and cert-manager-config helm chart ([a1476f2](https://github.com/albertoig/homelab/commit/a1476f21b3b47fd02f2765a26e643052d36d9752))
* **cert-manager:** update secret structure and add external-dns ([dacf54a](https://github.com/albertoig/homelab/commit/dacf54aac01354760bd190ccbcf28c5c1a6cc521))
* enable Prometheus monitoring for ArgoCD and Authentik with Grafana dashboards ([63a80e2](https://github.com/albertoig/homelab/commit/63a80e222977b334b7a60880eff9c2b281e5fa6e))
* enhance monitoring configuration for Grafana and Loki ([d2fb0e5](https://github.com/albertoig/homelab/commit/d2fb0e5e2498edeab63477fc34673d1c34aa5f4b))
* **grafana:** add MetalLB, Longhorn, and CoreDNS dashboards with updated node-exporter revision ([1ba1507](https://github.com/albertoig/homelab/commit/1ba1507e47ee40165029f0b0a6f30a269f2b5916))
* **helm:** add external-ingress chart for ingress management ([15ada8d](https://github.com/albertoig/homelab/commit/15ada8d190c921b1f2b644704bf0441c1e3a27d3))
* **helmfile:** add Longhorn storage, Loki logging, and Tempo tracing with breaking storage migration ([5201014](https://github.com/albertoig/homelab/commit/5201014391eb3f61b2683129db16594f755ac497))
* **helmfile:** add per-environment config system and consolidate values ([625c15c](https://github.com/albertoig/homelab/commit/625c15c84ef513fda175a1187c0559a3664fa30a))
* **helmfile:** add postgresql database deployment ([e2e5136](https://github.com/albertoig/homelab/commit/e2e5136aa33fb3137cb500e34297d844fa298ccf))
* **helmfile:** add Traefik reverse proxy and update external-dns configuration ([d92a82e](https://github.com/albertoig/homelab/commit/d92a82e5ad469d74428a34f220b2f2c96b443fa8))
* **helmfile:** make cert-manager cluster-issuer dynamic and enable Longhorn ingress in prod ([0dd7345](https://github.com/albertoig/homelab/commit/0dd7345bb99a8847f3beb03789da3ad2d9b10642))
* **helmfile:** upgrade Longhorn to v1.11.1 and disable telemetry ([64ec59c](https://github.com/albertoig/homelab/commit/64ec59c360f1a8859c6323cd9de94190e2c62eba))
* **infrastructure:** enable Traefik ingress for Grafana and add MetalLB support ([5caeea7](https://github.com/albertoig/homelab/commit/5caeea7639278c24aeeddbaa7c1d5f61ddef0ca7))
* **longhorn:** add Longhorn configuration with MetalLB UI exposure and Prometheus metrics ([258bfeb](https://github.com/albertoig/homelab/commit/258bfebe118cadb602a507926b9edd2dfcd6b525))
* **metal/k3s:** add k3s cluster provisioning via ansible ([b618907](https://github.com/albertoig/homelab/commit/b618907097fc8c584991759797ea0f956bd5898d))
* **metal/k3s:** disable built-in Traefik and klipper-lb in K3s cluster ([1d39235](https://github.com/albertoig/homelab/commit/1d3923514d3fa9dddc84d24b4e11b5c64d74ce2e))
* **monitoring:** add eBPF profiling and OTel tracing for ArgoCD and Grafana ([57f38c4](https://github.com/albertoig/homelab/commit/57f38c4d54525c79af5d407885dea91d84bc8b24))
* **monitoring:** add MetalLB load balancer for K3s cluster ([facd763](https://github.com/albertoig/homelab/commit/facd76357ce1e3ff1e7185ec6fd44145ef48a723))
* **monitoring:** add prometheus and grafana stack with sops encryption ([31956cf](https://github.com/albertoig/homelab/commit/31956cfcc28f99547bdc41e9053020549e859522))
* **monitoring:** add prometheus service monitors and update documentation ([6234de8](https://github.com/albertoig/homelab/commit/6234de8319adbaeab6f2de8b0e2d6ae63fca65c8))
* **monitoring:** add Pyroscope profiling, Tempo metrics-generator, and Alloy eBPF ([23ebaac](https://github.com/albertoig/homelab/commit/23ebaac403959b1d94ded68f0970f38cd570c7ce))
* **monitoring:** enable cross-signal correlation and TraceQL metrics ([6441faf](https://github.com/albertoig/homelab/commit/6441faf309b70dd03eb44d5236677608effc6ae5))
* **monitoring:** refactor helmfile to multi-env architecture with per-app config ([431ae2f](https://github.com/albertoig/homelab/commit/431ae2fb62f566785ac50c795c0dda035dcc5047))
* **monitoring:** upgrade Grafana LGTM stack and add Tempo datasource ([bf8bd3f](https://github.com/albertoig/homelab/commit/bf8bd3f8efc4afad170e3ce21a56474e4c35cb70))
* **pre-commit:** add commitlint hook for conventional commits ([44c028b](https://github.com/albertoig/homelab/commit/44c028b07489605483ad11dee0b2d8f95e76e853))
* **redis:** add bitnami redis chart to helmfile ([de459d4](https://github.com/albertoig/homelab/commit/de459d4ce0a493d3e858107521cae982f65c16b1))
* **release:** add beta branch and reset versioning ([1e80d4a](https://github.com/albertoig/homelab/commit/1e80d4a94cf365eb18183ec13faf628daadd39e6))
* **scripts:** add install/destroy orchestrators and requirement checks ([da0c030](https://github.com/albertoig/homelab/commit/da0c0307fa5142569a77ca7c958ad6ed9bf0838a))
* **secrets:** migrate to per-chart secrets architecture with interactive init ([eab70e6](https://github.com/albertoig/homelab/commit/eab70e61930fe0fac0c07a81f4dd89c237dda55a))


### BREAKING CHANGES

* Existing namespaces and their Helm release ownership
metadata must be migrated before deploying. ArgoCD CRD annotations
require manual patching of meta.helm.sh/release-namespace.
* Loki chart migrated from grafana/loki to grafana-community/loki (v6.54.0 → v9.2.2)

- Add Alloy as OpenTelemetry collector replacing promtail
- Configure Loki datasource with X-Scope-OrgID header
- Add ansible playbook for sysctl inotify tuning on K3s nodes
- Update helmfile lock files for dev and prod environments
* postgres and redis have been removed from the infrastructure.
* **monitoring:** helmfile structure moved from helm/ to helmfile/ with new templated layout

- Restructure flat helmfile.yaml into modular helmfile.yaml.gotmpl with bases
- Split monolithic prometheus values into separate prometheus-stack and grafana releases
- Extract env-specific values (replicas, storage, ingress) into per-environment overrides
- Add dedicated prometheus-operator-crds release for CRD lifecycle management
- Disable CRD management in kube-prometheus-stack to avoid conflicts
- Create per-release SOPS-encrypted secrets for dev and prod environments
- Fix template extension mismatch (.gotmpl vs .yaml.gotmpl) in templates.yaml
- Add Grafana datasource config pointing to prometheus-stack's Prometheus instance
- Wire up dev environment with local-path storage and reduced resource allocations
* **monitoring:** sensitive values must be encrypted with SOPS before deployment,
plain secrets files are not supported
