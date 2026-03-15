# CHANGELOG


## v3.1.0 (2026-03-15)

### Bug Fixes

- Semantic release
  ([`05b7a23`](https://github.com/albertoig/homelab/commit/05b7a232ee765caae85968a3bda74d296250f07f))

### Chores

- Add kseed tool
  ([`d2c1e3b`](https://github.com/albertoig/homelab/commit/d2c1e3bc1d8e85ed694ca44583bd37a0d9637e13))

### Features

- Add unit testing to kseed
  ([`dad27a2`](https://github.com/albertoig/homelab/commit/dad27a216b818cd7cc417076e676703971c3c78e))

- Rename test to diagnose
  ([`433be8e`](https://github.com/albertoig/homelab/commit/433be8e60c4cbf655e1b2e336c67e121e2dbbcda))

- Testing
  ([`35977ca`](https://github.com/albertoig/homelab/commit/35977cac37e09e3a1f196a87cf759a941fcd6b1e))

- Testing
  ([`fdf764c`](https://github.com/albertoig/homelab/commit/fdf764c9cd4bca887a9150094362765f53d877c0))


## v3.0.0 (2026-03-14)

### Chores

- **release**: 3.0.0 [skip ci]
  ([`bba94f2`](https://github.com/albertoig/homelab/commit/bba94f2004e7bf77e63d556aae26f6b8d38bb071))

# [3.0.0](https://github.com/albertoig/homelab/compare/v2.1.0...v3.0.0) (2026-03-14)

### Features

* deprecate helmfile infrastructure in favor of Pulumi with Python
  ([b7c8965](https://github.com/albertoig/homelab/commit/b7c896518e94d408b371dec2ef2fa927de874eac))

### BREAKING CHANGES

* helmfile directory is no longer supported. Please migrate to the new Pulumi-based infrastructure.

### Features

- Deprecate helmfile infrastructure in favor of Pulumi with Python
  ([`b7c8965`](https://github.com/albertoig/homelab/commit/b7c896518e94d408b371dec2ef2fa927de874eac))

- Remove helmfile-based deployment approach

BREAKING CHANGE: helmfile directory is no longer supported. Please migrate to the new Pulumi-based
  infrastructure.

### Breaking Changes

- Helmfile directory is no longer supported. Please migrate to the new Pulumi-based infrastructure.


## v2.1.0 (2026-03-13)

### Chores

- **release**: 2.1.0 [skip ci]
  ([`a0ed9aa`](https://github.com/albertoig/homelab/commit/a0ed9aa5588e99edd360dfd5ff8e40eb4bd7849c))

# [2.1.0](https://github.com/albertoig/homelab/compare/v2.0.0...v2.1.0) (2026-03-13)

### Features

* **authentik:** add Authentik identity provider to homelab
  ([9be209c](https://github.com/albertoig/homelab/commit/9be209cd7eef2d4e69b2e1432067f61df05bd37f))

### Features

- **authentik**: Add Authentik identity provider to homelab
  ([`9be209c`](https://github.com/albertoig/homelab/commit/9be209cd7eef2d4e69b2e1432067f61df05bd37f))

- Add Authentik Helm chart repository to repositories.yaml - Add authentik release configuration
  with namespace authentik - Add secret_key, email configuration in values - Add encrypted secrets
  for dev and prod environments

### Refactoring

- **helmfile**: Restructure lock files
  ([`645a44f`](https://github.com/albertoig/homelab/commit/645a44fa5e707e519a4f7ef8c75c190d242ba18e))

Refactored helmfile locks to use consistent naming convention and directory structure.


## v2.0.0 (2026-03-13)

### Chores

- Remove postgres and redis dependencies
  ([`8d20c14`](https://github.com/albertoig/homelab/commit/8d20c14a2e3d06fc9d6768159f86d3b9416c5c65))

BREAKING CHANGE: postgres and redis have been removed from the infrastructure.

- **helmfile**: Create lock file correctly on the lock folder for CRDS helmfile
  ([`b9b7cda`](https://github.com/albertoig/homelab/commit/b9b7cda2535f3a269c1b818b0c466bc9b7a32229))

- **release**: 2.0.0 [skip ci]
  ([`3513dd5`](https://github.com/albertoig/homelab/commit/3513dd5635dca8285debc9328c89997096ed7db6))

# [2.0.0](https://github.com/albertoig/homelab/compare/v1.6.0...v2.0.0) (2026-03-13)

### chore

* remove postgres and redis dependencies
  ([8d20c14](https://github.com/albertoig/homelab/commit/8d20c14a2e3d06fc9d6768159f86d3b9416c5c65))

### BREAKING CHANGES

* postgres and redis have been removed from the infrastructure.


## v1.6.0 (2026-03-13)

### Chores

- **release**: 1.6.0 [skip ci]
  ([`fcf0a81`](https://github.com/albertoig/homelab/commit/fcf0a8125cfbd37e45352ac0ac9af926a30c6c33))

# [1.6.0](https://github.com/albertoig/homelab/compare/v1.5.0...v1.6.0) (2026-03-13)

### Features

* **helmfile:** add postgresql database deployment
  ([e2e5136](https://github.com/albertoig/homelab/commit/e2e5136aa33fb3137cb500e34297d844fa298ccf))

### Features

- **helmfile**: Add postgresql database deployment
  ([`e2e5136`](https://github.com/albertoig/homelab/commit/e2e5136aa33fb3137cb500e34297d844fa298ccf))

- Add postgresql release to common.yaml.gotmpl with version 18.5.6 - Update dev and prod lock files
  with postgresql dependency - Uses bitnami/postgresql chart from existing repository - Deploys to
  postgresql namespace with longhorn storage


## v1.5.0 (2026-03-13)

### Chores

- **release**: 1.5.0 [skip ci]
  ([`2941457`](https://github.com/albertoig/homelab/commit/29414576957b8baad431d715355116c3acc5b8df))

# [1.5.0](https://github.com/albertoig/homelab/compare/v1.4.1...v1.5.0) (2026-03-13)

### Features

* **redis:** add bitnami redis chart to helmfile
  ([de459d4](https://github.com/albertoig/homelab/commit/de459d4ce0a493d3e858107521cae982f65c16b1))

### Features

- **redis**: Add bitnami redis chart to helmfile
  ([`de459d4`](https://github.com/albertoig/homelab/commit/de459d4ce0a493d3e858107521cae982f65c16b1))

- Add bitnami repository to repositories.yaml - Include redis release configuration in
  common.yaml.gotmpl - Configure persistence with longhorn storage - Enable Prometheus metrics via
  serviceMonitor


## v1.4.1 (2026-03-13)

### Bug Fixes

- **grafana**: Add correctly the admin password for grafana
  ([`520340b`](https://github.com/albertoig/homelab/commit/520340b47139ba903b62d65a7d3068aac47719df))

- Changed Helm chart values docs for grafana-community/grafana - Renamed grafanaAdminPassword to
  adminPassword - Removed grafanaSecretKey (no longer required by community chart)

### Chores

- **metallb**: Remove obsolete comments from configuration files
  ([`5b5bfa0`](https://github.com/albertoig/homelab/commit/5b5bfa02b0b19dc557f05694af0a198e88865a8d))

- Remove AddressPool note from common metallb.yaml.gotmpl - Remove environment comments from dev
  metallb-config.yaml.gotmpl - Remove environment comments from prod metallb-config.yaml.gotmpl

- **release**: 1.4.1 [skip ci]
  ([`47b8366`](https://github.com/albertoig/homelab/commit/47b8366795bdcf26ea14dbe8db23b65b9b446d79))

## [1.4.1](https://github.com/albertoig/homelab/compare/v1.4.0...v1.4.1) (2026-03-13)

### Bug Fixes

* **grafana:** add correctly the admin password for grafana
  ([520340b](https://github.com/albertoig/homelab/commit/520340b47139ba903b62d65a7d3068aac47719df))


## v1.4.0 (2026-03-12)

### Chores

- **metallb-config**: Relocate chart to charts directory and update version to 0.15.3
  ([`7e30ae8`](https://github.com/albertoig/homelab/commit/7e30ae821a810e45edc9aff3ac7558b729e0a116))

- **release**: 1.4.0 [skip ci]
  ([`006b13a`](https://github.com/albertoig/homelab/commit/006b13accc557dc50271c11e380756e198f38782))

# [1.4.0](https://github.com/albertoig/homelab/compare/v1.3.0...v1.4.0) (2026-03-12)

### Features

* **grafana:** add MetalLB, Longhorn, and CoreDNS dashboards with updated node-exporter revision
  ([1ba1507](https://github.com/albertoig/homelab/commit/1ba1507e47ee40165029f0b0a6f30a269f2b5916))
  * **longhorn:** add Longhorn configuration with MetalLB UI exposure and Prometheus metrics
  ([258bfeb](https://github.com/albertoig/homelab/commit/258bfebe118cadb602a507926b9edd2dfcd6b525))

### Features

- **grafana**: Add MetalLB, Longhorn, and CoreDNS dashboards with updated node-exporter revision
  ([`1ba1507`](https://github.com/albertoig/homelab/commit/1ba1507e47ee40165029f0b0a6f30a269f2b5916))

- Update node-exporter dashboard from revision 37 to 42 - Add MetalLB dashboard (gnetId: 20162,
  revision: 6) - Add Longhorn dashboard (gnetId: 16888, revision: 11) - Add CoreDNS dashboard
  (gnetId: 15762, revision: 22) - Add Kubernetes pods dashboard (gnetId: 6417, revision: 1)

- **longhorn**: Add Longhorn configuration with MetalLB UI exposure and Prometheus metrics
  ([`258bfeb`](https://github.com/albertoig/homelab/commit/258bfebe118cadb602a507926b9edd2dfcd6b525))

- Add LoadBalancer service for Longhorn UI with MetalLB annotations - Enable Prometheus
  ServiceMonitor for metrics scraping - Configure 15s interval and 10s scrape timeout - Set Longhorn
  UI replica count to 1


## v1.3.0 (2026-03-12)

### Chores

- **release**: 1.3.0 [skip ci]
  ([`3dc6d5c`](https://github.com/albertoig/homelab/commit/3dc6d5c3318f244bdad28b001d13d5173cca33e9))

# [1.3.0](https://github.com/albertoig/homelab/compare/v1.2.1...v1.3.0) (2026-03-12)

### Features

* **helmfile:** add Longhorn storage, Loki logging, and Tempo tracing with breaking storage
  migration
  ([5201014](https://github.com/albertoig/homelab/commit/5201014391eb3f61b2683129db16594f755ac497))

### Features

- **helmfile**: Add Longhorn storage, Loki logging, and Tempo tracing with breaking storage
  migration
  ([`5201014`](https://github.com/albertoig/homelab/commit/5201014391eb3f61b2683129db16594f755ac497))

- Storage class migration: Changed from `local-path` to `longhorn` for all persistent volumes
  (Grafana, Prometheus, AlertManager) - Grafana chart migration: Moved from `grafana/grafana`
  (v7.3.7) to `grafana-community/grafana` (v11.3.2) - MetalLB configuration: Changed from inline
  config to separate CRDs via custom Helm chart

- add Longhorn cloud-native distributed block storage (v1.7.1) - add Loki log aggregation system
  (v6.54.0) with Grafana datasource - add Tempo distributed tracing system (v2.0.0) - add
  MetalLB-config custom Helm chart for IP Address Pool and L2Advertisement CRDs - add Prometheus
  Operator CRDs as separate helmfile for proper install ordering - add waitForJobs: true to
  helmDefaults

- Update helmfile.yaml.gotmpl to include CRDs helmfile and waitForJobs - Add grafana-community and
  longhorn helm repositories - Configure environment-specific MetalLB IP pools (dev: 10.0.0.150-160,
  prod: 10.0.0.161-170) - Update grafana values with Longhorn storage, Loki datasource, and token
  rotation settings

- Add docs/IMPORTANT.md with Longhorn volume destruction warning and cleanup instructions


## v1.2.1 (2026-03-11)

### Bug Fixes

- **monitoring**: Change storage from gp2 to local-path for K3s compatibility
  ([`ec93f86`](https://github.com/albertoig/homelab/commit/ec93f865283229803cfa2c11cb1cc11e47e5c572))

- Update prometheus and alertmanager storageClassName from gp2 to local-path - Reduce prometheus
  storage from 50Gi to 20Gi for home lab usage - Add MetalLB Service and ServiceMonitor to common
  values for Prometheus scraping

### Chores

- **release**: 1.2.1 [skip ci]
  ([`3f87c54`](https://github.com/albertoig/homelab/commit/3f87c546094d0329cb0810002198cb0cc127cb71))

## [1.2.1](https://github.com/albertoig/homelab/compare/v1.2.0...v1.2.1) (2026-03-11)

### Bug Fixes

* **monitoring:** change storage from gp2 to local-path for K3s compatibility
  ([ec93f86](https://github.com/albertoig/homelab/commit/ec93f865283229803cfa2c11cb1cc11e47e5c572))


## v1.2.0 (2026-03-11)

### Chores

- **release**: 1.2.0 [skip ci]
  ([`7730b5f`](https://github.com/albertoig/homelab/commit/7730b5f8b0fe6a13263db945c33503cac00cb27b))

# [1.2.0](https://github.com/albertoig/homelab/compare/v1.1.0...v1.2.0) (2026-03-11)

### Features

* **metal/k3s:** disable built-in Traefik and klipper-lb in K3s cluster
  ([1d39235](https://github.com/albertoig/homelab/commit/1d3923514d3fa9dddc84d24b4e11b5c64d74ce2e))

### Features

- **metal/k3s**: Disable built-in Traefik and klipper-lb in K3s cluster
  ([`1d39235`](https://github.com/albertoig/homelab/commit/1d3923514d3fa9dddc84d24b4e11b5c64d74ce2e))

- Add server_config_yaml to disable traefik and servicelb components - This allows MetalLB to handle
  LoadBalancer services exclusively - Eliminates port conflicts between klipper-lb and MetalLB


## v1.1.0 (2026-03-11)

### Chores

- Change license to GPL v3
  ([`f812934`](https://github.com/albertoig/homelab/commit/f812934162826a46e9274c271f750a8a6e499d9a))

- **release**: 1.1.0 [skip ci]
  ([`fa31c37`](https://github.com/albertoig/homelab/commit/fa31c373a76fb54ecffd8a3940d498c4493e74d7))

# [1.1.0](https://github.com/albertoig/homelab/compare/v1.0.0...v1.1.0) (2026-03-11)

### Features

* **monitoring:** add MetalLB load balancer for K3s cluster
  ([facd763](https://github.com/albertoig/homelab/commit/facd76357ce1e3ff1e7185ec6fd44145ef48a723))

### Features

- **monitoring**: Add MetalLB load balancer for K3s cluster
  ([`facd763`](https://github.com/albertoig/homelab/commit/facd76357ce1e3ff1e7185ec6fd44145ef48a723))

- Add MetalLB v0.15.3 helm release with IPAddressPool and L2Advertisement CRDs - Configure Grafana
  service type as LoadBalancer with MetalLB annotations - Use k3s.cattle.io/balancer annotation to
  disable built-in klipper-lb - Add environment-specific IP ranges - Configure prod Grafana to use
  port 30080 to avoid Traefik port conflicts

### Refactoring

- **helmfile**: Migrate YAML templates to .gotmpl and centralize storage configuration
  ([`e498c55`](https://github.com/albertoig/homelab/commit/e498c55fa1cf1749e46ace2da8ec704a2fad2463))

- Convert helmfile/environments.yaml and helmfile/templates.yaml to .gotmpl templates - Move
  storageClassName from environment-specific to common grafana values - Add server-side dry-run for
  helmfile diff - Remove legacy YAML template files


## v1.0.0 (2026-03-10)

### Chores

- **release**: 1.0.0 [skip ci]
  ([`b0dd2f1`](https://github.com/albertoig/homelab/commit/b0dd2f1944451aceec51e79c34f8daadb1faf254))

# 1.0.0 (2026-03-10)

### Features

* **metal/k3s:** add k3s cluster provisioning via ansible
  ([b618907](https://github.com/albertoig/homelab/commit/b618907097fc8c584991759797ea0f956bd5898d))
  * **monitoring:** add prometheus and grafana stack with sops encryption
  ([31956cf](https://github.com/albertoig/homelab/commit/31956cfcc28f99547bdc41e9053020549e859522))
  * **monitoring:** refactor helmfile to multi-env architecture with per-app config
  ([431ae2f](https://github.com/albertoig/homelab/commit/431ae2fb62f566785ac50c795c0dda035dcc5047))

### BREAKING CHANGES

* **monitoring:** helmfile structure moved from helm/ to helmfile/ with new templated layout

- Restructure flat helmfile.yaml into modular helmfile.yaml.gotmpl with bases - Split monolithic
  prometheus values into separate prometheus-stack and grafana releases - Extract env-specific
  values (replicas, storage, ingress) into per-environment overrides - Add dedicated
  prometheus-operator-crds release for CRD lifecycle management - Disable CRD management in
  kube-prometheus-stack to avoid conflicts - Create per-release SOPS-encrypted secrets for dev and
  prod environments - Fix template extension mismatch (.gotmpl vs .yaml.gotmpl) in templates.yaml -
  Add Grafana datasource config pointing to prometheus-stack's Prometheus instance - Wire up dev
  environment with local-path storage and reduced resource allocations * **monitoring:** sensitive
  values must be encrypted with SOPS before deployment, plain secrets files are not supported

### Continuous Integration

- **release**: Add semantic release automation with caching
  ([`8eb56d2`](https://github.com/albertoig/homelab/commit/8eb56d2f6305c3416f55634a54ff8a222ce8a010))

Set up semantic release to automate version management and changelog generation. Includes GitHub
  Actions workflow with npm caching to improve pipeline performance.

- add .releaserc.json with semantic release plugins configuration - add release workflow with
  node_modules caching strategy - add package.json with semantic release dependencies - add
  package-lock.json for deterministic installs and cache key hashing - add .gitignore to exclude
  node_modules and logs

- **release**: Update branch reference in GitHub Actions
  ([`4016b00`](https://github.com/albertoig/homelab/commit/4016b00cab59f33cb14cf8be7158e9b53c3e36b7))

### Documentation

- Add README and ROADMAP files
  ([`6e2f0f8`](https://github.com/albertoig/homelab/commit/6e2f0f8dd30370ce6e4a74c96e8e19e2e8f3e620))

- Add initial README with project overview, tech stack and getting started guide - Add ROADMAP with
  completed tasks, in progress and planned features - Add Q1-Q4 2026 timeline

- Update README and ROADMAP files
  ([`74a74b8`](https://github.com/albertoig/homelab/commit/74a74b861a42f51f03cc89bd3e5e655b880bc664))

- **metal/k3s**: Fix setup guide order and add ssh hardening step
  ([`1287457`](https://github.com/albertoig/homelab/commit/1287457c7bc2334498cbc88b6da187176d68adf6))

Move SSH key generation and copy (Part 2) before SSH hardening (formerly 1.4) so the guide follows a
  logical order. You cannot disable password authentication before copying your public key to the
  node.

- Move SSH hardening into Part 2.3 after key copy is confirmed working - Add warning to verify key
  login in a second terminal before restarting sshd to prevent lockout - Add missing netplan static
  IP configuration block to section 1.2 - Reorder parts so flow is: prepare machines → ssh keys →
  configure → deploy

### Features

- **metal/k3s**: Add k3s cluster provisioning via ansible
  ([`b618907`](https://github.com/albertoig/homelab/commit/b618907097fc8c584991759797ea0f956bd5898d))

Set up bare metal k3s cluster provisioning using the official k3s-ansible collection. Includes
  encrypted secrets management with SOPS, SSH key authentication, passwordless sudo, and a single
  script entrypoint.

- Add requirements.yml with k3s-ansible pinned to e9e0978 for reproducibility alongside
  kubernetes.core and ansible.utils collections - Add inventory.example.yml as a safe template with
  inline documentation for all required fields including token generation instructions - Add
  ansible.cfg with sane defaults for ssh pipelining and collections - Add run.sh as single
  entrypoint that handles SSH agent setup, SOPS decryption, collection installation, inventory
  validation, connectivity checks and playbook execution with automatic plaintext cleanup via trap -
  Add .gitignore to exclude plaintext inventory, SSH keys, ansible runtime artifacts and SOPS age
  private key - Add .sops.yaml with encryption rules scoped to metal/k3s inventory - Add README.md
  with beginner friendly step by step guide covering OS setup, static IP configuration, passwordless
  sudo, SSH key generation, SOPS encryption setup, cluster deployment and troubleshooting

- **monitoring**: Add prometheus and grafana stack with sops encryption
  ([`31956cf`](https://github.com/albertoig/homelab/commit/31956cfcc28f99547bdc41e9053020549e859522))

Set up monitoring infrastructure using helmfile with kube-prometheus-stack and SOPS encryption for
  sensitive values management.

- Add helmfile configuration for kube-prometheus-stack deployment - Enable built-in Grafana from
  kube-prometheus-stack chart - Configure Prometheus with persistent storage and scrape configs -
  Add multi-environment support (dev/prod) with environment-specific values (only prod for now) -
  Encrypt sensitive values using SOPS with Age key encryption - Add pre-loaded Grafana dashboards
  for kubernetes cluster, node exporter and pods - Add .gitignore rules to prevent plain secret
  files from being committed

BREAKING CHANGE: sensitive values must be encrypted with SOPS before deployment, plain secrets files
  are not supported

- **monitoring**: Refactor helmfile to multi-env architecture with per-app config
  ([`431ae2f`](https://github.com/albertoig/homelab/commit/431ae2fb62f566785ac50c795c0dda035dcc5047))

BREAKING CHANGE: helmfile structure moved from helm/ to helmfile/ with new templated layout

- Restructure flat helmfile.yaml into modular helmfile.yaml.gotmpl with bases - Split monolithic
  prometheus values into separate prometheus-stack and grafana releases - Extract env-specific
  values (replicas, storage, ingress) into per-environment overrides - Add dedicated
  prometheus-operator-crds release for CRD lifecycle management - Disable CRD management in
  kube-prometheus-stack to avoid conflicts - Create per-release SOPS-encrypted secrets for dev and
  prod environments - Fix template extension mismatch (.gotmpl vs .yaml.gotmpl) in templates.yaml -
  Add Grafana datasource config pointing to prometheus-stack's Prometheus instance - Wire up dev
  environment with local-path storage and reduced resource allocations

### Breaking Changes

- **monitoring**: Helmfile structure moved from helm/ to helmfile/ with new templated layout
