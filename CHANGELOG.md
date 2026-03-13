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
