# [4.3.0](https://github.com/albertoig/homelab/compare/v4.2.0...v4.3.0) (2026-03-30)


### Features

* **monitoring:** enable cross-signal correlation and TraceQL metrics ([6441faf](https://github.com/albertoig/homelab/commit/6441faf309b70dd03eb44d5236677608effc6ae5))

# [4.2.0](https://github.com/albertoig/homelab/compare/v4.1.0...v4.2.0) (2026-03-30)


### Features

* **monitoring:** add Pyroscope profiling, Tempo metrics-generator, and Alloy eBPF ([23ebaac](https://github.com/albertoig/homelab/commit/23ebaac403959b1d94ded68f0970f38cd570c7ce))

# [4.1.0](https://github.com/albertoig/homelab/compare/v4.0.0...v4.1.0) (2026-03-30)


### Features

* **monitoring:** upgrade Grafana LGTM stack and add Tempo datasource ([bf8bd3f](https://github.com/albertoig/homelab/commit/bf8bd3f8efc4afad170e3ce21a56474e4c35cb70))

# [4.0.0](https://github.com/albertoig/homelab/compare/v3.16.0...v4.0.0) (2026-03-29)


* feat(monitoring)!: migrate Loki to v9, add Alloy collector, and tune sysctl ([ba83486](https://github.com/albertoig/homelab/commit/ba834866bcd533d92dd26139ba2d98f663783e59))


### BREAKING CHANGES

* Loki chart migrated from grafana/loki to grafana-community/loki (v6.54.0 → v9.2.2)

- Add Alloy as OpenTelemetry collector replacing promtail
- Configure Loki datasource with X-Scope-OrgID header
- Add ansible playbook for sysctl inotify tuning on K3s nodes
- Update helmfile lock files for dev and prod environments

# [3.16.0](https://github.com/albertoig/homelab/compare/v3.15.0...v3.16.0) (2026-03-29)


### Features

* **monitoring:** add prometheus service monitors and update documentation ([6234de8](https://github.com/albertoig/homelab/commit/6234de8319adbaeab6f2de8b0e2d6ae63fca65c8))

# [3.15.0](https://github.com/albertoig/homelab/compare/v3.14.0...v3.15.0) (2026-03-29)


### Features

* enhance monitoring configuration for Grafana and Loki ([d2fb0e5](https://github.com/albertoig/homelab/commit/d2fb0e5e2498edeab63477fc34673d1c34aa5f4b))

# [3.14.0](https://github.com/albertoig/homelab/compare/v3.13.0...v3.14.0) (2026-03-28)


### Features

* enable Prometheus monitoring for ArgoCD and Authentik with Grafana dashboards ([63a80e2](https://github.com/albertoig/homelab/commit/63a80e222977b334b7a60880eff9c2b281e5fa6e))

# [3.13.0](https://github.com/albertoig/homelab/compare/v3.12.0...v3.13.0) (2026-03-28)


### Features

* add external-dns monitoring and Grafana dashboard ([95f3e57](https://github.com/albertoig/homelab/commit/95f3e57563e23bc7ad40e8a7306656e236b183e1))

# [3.12.0](https://github.com/albertoig/homelab/compare/v3.11.0...v3.12.0) (2026-03-28)


### Features

* add ArgoCD GitOps continuous delivery platform ([cffeffd](https://github.com/albertoig/homelab/commit/cffeffd7dcbba4ab167443d6e0f0badf415edbe7))

# [3.11.0](https://github.com/albertoig/homelab/compare/v3.10.0...v3.11.0) (2026-03-27)


### Features

* **helmfile:** upgrade Longhorn to v1.11.1 and disable telemetry ([64ec59c](https://github.com/albertoig/homelab/commit/64ec59c360f1a8859c6323cd9de94190e2c62eba))

# [3.10.0](https://github.com/albertoig/homelab/compare/v3.9.0...v3.10.0) (2026-03-26)


### Features

* **helmfile:** make cert-manager cluster-issuer dynamic and enable Longhorn ingress in prod ([0dd7345](https://github.com/albertoig/homelab/commit/0dd7345bb99a8847f3beb03789da3ad2d9b10642))

# [3.9.0](https://github.com/albertoig/homelab/compare/v3.8.0...v3.9.0) (2026-03-26)


### Features

* **helm:** add external-ingress chart for ingress management ([15ada8d](https://github.com/albertoig/homelab/commit/15ada8d190c921b1f2b644704bf0441c1e3a27d3))

# [3.8.0](https://github.com/albertoig/homelab/compare/v3.7.0...v3.8.0) (2026-03-24)


### Features

* **infrastructure:** enable Traefik ingress for Grafana and add MetalLB support ([5caeea7](https://github.com/albertoig/homelab/commit/5caeea7639278c24aeeddbaa7c1d5f61ddef0ca7))

# [3.7.0](https://github.com/albertoig/homelab/compare/v3.6.0...v3.7.0) (2026-03-21)


### Features

* **helmfile:** add Traefik reverse proxy and update external-dns configuration ([d92a82e](https://github.com/albertoig/homelab/commit/d92a82e5ad469d74428a34f220b2f2c96b443fa8))

# [3.6.0](https://github.com/albertoig/homelab/compare/v3.5.0...v3.6.0) (2026-03-20)


### Features

* **cert-manager:** update secret structure and add external-dns ([dacf54a](https://github.com/albertoig/homelab/commit/dacf54aac01354760bd190ccbcf28c5c1a6cc521))

# [3.5.0](https://github.com/albertoig/homelab/compare/v3.4.1...v3.5.0) (2026-03-20)


### Features

* **cert-manager:** add cert-manager and cert-manager-config helm chart ([a1476f2](https://github.com/albertoig/homelab/commit/a1476f21b3b47fd02f2765a26e643052d36d9752))

## [3.4.1](https://github.com/albertoig/homelab/compare/v3.4.0...v3.4.1) (2026-03-20)


### Reverts

* Revert "3.1.0" ([958766d](https://github.com/albertoig/homelab/commit/958766d81792bdf30697b34da780aa976c196b27))
* Revert "chore: add CI/CD pipelines and contributor documentation" ([ab7bd0e](https://github.com/albertoig/homelab/commit/ab7bd0ed33f23ddbdea662e56eb88f14747f3ff6))
* Revert "chore: Add kseed tool" ([0c88d9f](https://github.com/albertoig/homelab/commit/0c88d9ff2f0ec1cd83c26f398f27e60b30d98d3b))
* Revert "chore: Add pull request template" ([1e76c93](https://github.com/albertoig/homelab/commit/1e76c9367c0d3f08601b7439157d66b9bed81035))
* Revert "chore(deps): bump actions/checkout from 4 to 6" ([452ba80](https://github.com/albertoig/homelab/commit/452ba80a2beedaebe4a4cee09041691dfb9ad8f2))
* Revert "chore(deps): bump actions/setup-python from 5 to 6" ([7622e66](https://github.com/albertoig/homelab/commit/7622e66be4a94506b65dd96dff012380b778c3a6))
* Revert "chore(deps): bump codecov/codecov-action from 4 to 5" ([03ab263](https://github.com/albertoig/homelab/commit/03ab2633606451209fbb65ac22e6907daa1469cb))
* Revert "chore(release): 2.1.0 [skip ci]" ([44d57be](https://github.com/albertoig/homelab/commit/44d57befc2318b5038e7d45a9f5162088b2064a9))
* Revert "chore(release): 3.0.0 [skip ci]" ([78f09ef](https://github.com/albertoig/homelab/commit/78f09efe89145dbb1da1afd319c93ff694480c67))
* Revert "feat: add CI pipeline" ([f004148](https://github.com/albertoig/homelab/commit/f004148aba2dd88158e898579d5d69f6ac932dd0))
* Revert "feat: add SR step in the CD" ([8bc9b6b](https://github.com/albertoig/homelab/commit/8bc9b6bf20df556d9a989c79696fb056c86332b7))
* Revert "feat: add unit testing to kseed" ([d3bafee](https://github.com/albertoig/homelab/commit/d3bafee2d0d6f4565772e2b23bc3da9ed07d927c))
* Revert "feat: deprecate helmfile infrastructure in favor of Pulumi with Python" ([c21ae78](https://github.com/albertoig/homelab/commit/c21ae785ed014ab8648dcbf82d907241ea3b7eab))
* Revert "feat: improving documentation" ([928de38](https://github.com/albertoig/homelab/commit/928de38dc64158981bad54c33c0c1657c3e1c2a3))
* Revert "feat: rename test to diagnose" ([a8cf0c0](https://github.com/albertoig/homelab/commit/a8cf0c072b6d618478c159d80bd74ca44dfc3438))
* Revert "feat: testing" ([6bfc484](https://github.com/albertoig/homelab/commit/6bfc484d5e4ac08e58a269701e33d509cb481e33))
* Revert "feat: testing" ([2320ac5](https://github.com/albertoig/homelab/commit/2320ac522c07307b535c7d964f93302d06e57484))
* Revert "fix: fix lint" ([34a5152](https://github.com/albertoig/homelab/commit/34a5152bfa3c04f2a8f4a29cf5a3ef682578970a))
* Revert "fix: now the diagnose function works correctly in the CLI" ([213ef4f](https://github.com/albertoig/homelab/commit/213ef4f84a0cb4c0fc3510a441a49954e12069f2))
* Revert "fix: python format" ([e3e70a3](https://github.com/albertoig/homelab/commit/e3e70a36cbce15ba8f062f547c7a08498c3e127b))
* Revert "fix: semantic release" ([949accd](https://github.com/albertoig/homelab/commit/949accdb10742624cab00c797290d59348a99aed))
* Revert "fix(ci): remove invalid allow-dependencies-licenses parameter" ([efb3305](https://github.com/albertoig/homelab/commit/efb3305a679805c5bd8d6f038aaf35a06725ee5e))

# [2.0.0](https://github.com/albertoig/homelab/compare/v1.6.0...v2.0.0) (2026-03-13)


### chore

* remove postgres and redis dependencies ([8d20c14](https://github.com/albertoig/homelab/commit/8d20c14a2e3d06fc9d6768159f86d3b9416c5c65))


### BREAKING CHANGES

* postgres and redis have been removed from the infrastructure.

# [1.6.0](https://github.com/albertoig/homelab/compare/v1.5.0...v1.6.0) (2026-03-13)


### Features

* **helmfile:** add postgresql database deployment ([e2e5136](https://github.com/albertoig/homelab/commit/e2e5136aa33fb3137cb500e34297d844fa298ccf))

# [1.5.0](https://github.com/albertoig/homelab/compare/v1.4.1...v1.5.0) (2026-03-13)


### Features

* **redis:** add bitnami redis chart to helmfile ([de459d4](https://github.com/albertoig/homelab/commit/de459d4ce0a493d3e858107521cae982f65c16b1))

## [1.4.1](https://github.com/albertoig/homelab/compare/v1.4.0...v1.4.1) (2026-03-13)


### Bug Fixes

* **grafana:** add correctly the admin password for grafana ([520340b](https://github.com/albertoig/homelab/commit/520340b47139ba903b62d65a7d3068aac47719df))

# [1.4.0](https://github.com/albertoig/homelab/compare/v1.3.0...v1.4.0) (2026-03-12)


### Features

* **grafana:** add MetalLB, Longhorn, and CoreDNS dashboards with updated node-exporter revision ([1ba1507](https://github.com/albertoig/homelab/commit/1ba1507e47ee40165029f0b0a6f30a269f2b5916))
* **longhorn:** add Longhorn configuration with MetalLB UI exposure and Prometheus metrics ([258bfeb](https://github.com/albertoig/homelab/commit/258bfebe118cadb602a507926b9edd2dfcd6b525))

# [1.3.0](https://github.com/albertoig/homelab/compare/v1.2.1...v1.3.0) (2026-03-12)


### Features

* **helmfile:** add Longhorn storage, Loki logging, and Tempo tracing with breaking storage migration ([5201014](https://github.com/albertoig/homelab/commit/5201014391eb3f61b2683129db16594f755ac497))

## [1.2.1](https://github.com/albertoig/homelab/compare/v1.2.0...v1.2.1) (2026-03-11)


### Bug Fixes

* **monitoring:** change storage from gp2 to local-path for K3s compatibility ([ec93f86](https://github.com/albertoig/homelab/commit/ec93f865283229803cfa2c11cb1cc11e47e5c572))

# [1.2.0](https://github.com/albertoig/homelab/compare/v1.1.0...v1.2.0) (2026-03-11)


### Features

* **metal/k3s:** disable built-in Traefik and klipper-lb in K3s cluster ([1d39235](https://github.com/albertoig/homelab/commit/1d3923514d3fa9dddc84d24b4e11b5c64d74ce2e))

# [1.1.0](https://github.com/albertoig/homelab/compare/v1.0.0...v1.1.0) (2026-03-11)


### Features

* **monitoring:** add MetalLB load balancer for K3s cluster ([facd763](https://github.com/albertoig/homelab/commit/facd76357ce1e3ff1e7185ec6fd44145ef48a723))

# 1.0.0 (2026-03-10)


### Features

* **metal/k3s:** add k3s cluster provisioning via ansible ([b618907](https://github.com/albertoig/homelab/commit/b618907097fc8c584991759797ea0f956bd5898d))
* **monitoring:** add prometheus and grafana stack with sops encryption ([31956cf](https://github.com/albertoig/homelab/commit/31956cfcc28f99547bdc41e9053020549e859522))
* **monitoring:** refactor helmfile to multi-env architecture with per-app config ([431ae2f](https://github.com/albertoig/homelab/commit/431ae2fb62f566785ac50c795c0dda035dcc5047))


### BREAKING CHANGES

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
