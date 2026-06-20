## [1.0.1-beta.1](https://github.com/albertoig/homelab/compare/v1.0.0...v1.0.1-beta.1) (2026-06-20)


### Bug Fixes

* **authentik:** add required digits field to TOTP setup stage ([a47b0e8](https://github.com/albertoig/homelab/commit/a47b0e8b9e2e031aee80e901abd23c6b98ac87a2))
* **authentik:** enable automatic_apply on SSO blueprint ([d4b31cb](https://github.com/albertoig/homelab/commit/d4b31cb0fcae172b2858dcaab96e5a0dd228da8c))
* **authentik:** enforce TOTP MFA on first login via blueprint ([d5a2581](https://github.com/albertoig/homelab/commit/d5a25810ac0bca1338bad8245feceaaf7f90e198))
* **ci:** handle force-push in commitlint by checking ancestor before using FROM sha ([55105a1](https://github.com/albertoig/homelab/commit/55105a1f4594be11aa8df62c247fcbaae09c10ca))
* **ci:** run shell BDD tests via mise task with --kcov flag ([23eca0e](https://github.com/albertoig/homelab/commit/23eca0eca406f56940df1dc375e7485fd258274e))
* **env:** read the environment selector from /dev/tty to stop escape leaks ([ab93f05](https://github.com/albertoig/homelab/commit/ab93f055e26dd0c87aea5bcd46dfb42fb5250a17))
* **grafana:** use Recreate strategy to prevent RWO multi-attach errors ([9058b07](https://github.com/albertoig/homelab/commit/9058b07711ee7b92cdce4ae03c389b6365773ed9))
* **loki:** enable auth_enabled for multi-tenancy ([b50652b](https://github.com/albertoig/homelab/commit/b50652b487c6864ec49bb879eedc91a00597edba))
* **metal:** pin all Ansible Galaxy collection versions to avoid API lookup errors ([5d4dc82](https://github.com/albertoig/homelab/commit/5d4dc82c931434039e1e417e91c2bf56682c84b9))
* **mise:** auto-init Terraform backend before workspace select and apply ([a3e3524](https://github.com/albertoig/homelab/commit/a3e3524372b32637abba013eede20edf113b2543))
* **mise:** correct kubectl version, add pipx as explicit dependency ([4de3517](https://github.com/albertoig/homelab/commit/4de35179afacce890218015c5fc77f9fc65cbe59))
* **mise:** move install/destroy logic to scripts so env arg is passed correctly ([51fd1b9](https://github.com/albertoig/homelab/commit/51fd1b9fcec8375be80fd1cfddca42bc9862fc38))
* **mise:** replace source with . for POSIX sh compatibility and use return in sourced script ([f142054](https://github.com/albertoig/homelab/commit/f142054f0e670ce9b744aecbcaa6a19c1ee32f32))
* **mise:** replace uvx with poetry for Python tool management ([6a37588](https://github.com/albertoig/homelab/commit/6a37588b0eeeb5e74856ff9ec659c13a5d62f939))
* **mise:** switch Python tools from pipx to uvx backend ([5779f9a](https://github.com/albertoig/homelab/commit/5779f9afee756b52b744574dbcea942933549d3c))
* **mise:** use CLOUDFLARE_ACCOUNT_ID to derive R2 endpoint and account ID for Terraform ([528c4f5](https://github.com/albertoig/homelab/commit/528c4f57f2d693d590b0d342eca97a537e31f703))
* **mise:** use TF_WORKSPACE and single-line tasks to fix env arg across all terraform commands ([7cf3281](https://github.com/albertoig/homelab/commit/7cf32813d40876c9812b7ae0be157381f7846438))
* **openbao:** disable the unused agent injector to stop upgrade conflicts ([805e313](https://github.com/albertoig/homelab/commit/805e3131501495dafddc99b2b9c9709b4f9f94cd))
* **openbao:** store data under the mounted /openbao/data path ([781c249](https://github.com/albertoig/homelab/commit/781c249c735d0e28566927c95bec41263e9265d6))
* **openbao:** wait for openbao-0 to be Running instead of Ready before unsealing ([1cfaf56](https://github.com/albertoig/homelab/commit/1cfaf5694563373584d860f6c98c3a67fceb77fe))
* **openbao:** wire ESO with external-secrets.io/v1 and make setup idempotent ([2af64ce](https://github.com/albertoig/homelab/commit/2af64ced47234a4a6dbc8282001d9aa09ceab07a))
* **scripts:** always prompt before each chart in init-secrets ([3421fee](https://github.com/albertoig/homelab/commit/3421fee4c1726f8f0ca4fbfa5f6ae32ad8fe8fc8))
* **scripts:** harden init-secrets security and correctness ([4491d16](https://github.com/albertoig/homelab/commit/4491d16105a73b29ea3d9f58ac7b8e9d7cef1e81))
* **scripts:** remove default env arg so init-secrets shows the selector ([6034f7a](https://github.com/albertoig/homelab/commit/6034f7ae2cb3416632fefe4eeb77ea4829195279))
* **terraform:** extract R2 credential mapping to scripts/lib/terraform-env.sh ([5e39c1c](https://github.com/albertoig/homelab/commit/5e39c1c048c3473e37cc6807182c82d6ddb2df48))
* **terraform:** replace deprecated force_path_style and skip backend when credentials absent ([6c2bbfc](https://github.com/albertoig/homelab/commit/6c2bbfc3bfbe7f9f4472ee481a6aaf51ce3c579c))
* **terraform:** use -migrate-state on init and skip AWS account ID lookup for R2 ([cd602a8](https://github.com/albertoig/homelab/commit/cd602a89f99f82661fd592cc2d9f743609fa1969))
* **terraform:** use CLOUDFLARE_R2_* vars instead of AWS_* for R2 state backend ([73ce154](https://github.com/albertoig/homelab/commit/73ce1541d831dd79e83fc042d8d1a2482d2174c8))


### Features

* add animated image header to CLI scripts via viu ([eb7bae8](https://github.com/albertoig/homelab/commit/eb7bae808de2ca9c3a2628605fa12df3b7d4b3a9))
* add velero secrets automation and fix terraform workspace selection ([53b48f9](https://github.com/albertoig/homelab/commit/53b48f9137105163115e6ca38e1d378f54f162ba))
* **check:** add side-by-side Tools and Secrets boxes with env-scoped secrets check ([8b286ca](https://github.com/albertoig/homelab/commit/8b286ca3454a8e30c692ae6b370445cbd1c86247))
* **check:** per-item results in equal-height boxes with BDD coverage ([3dd99f4](https://github.com/albertoig/homelab/commit/3dd99f43fd8bdf735a4f379f31df48825d0de48c))
* **check:** redesign requisites UI with gum spin pulse and section ticks ([d329fdb](https://github.com/albertoig/homelab/commit/d329fdb5e7579e592cafdd31713b44174293e19c))
* **doctor:** replace helmfile remediation hooks with on-demand cluster doctor ([f37f625](https://github.com/albertoig/homelab/commit/f37f625dc8d1748025d755e31fb2a0a9c5dfde81))
* **header:** replace image banner with retro ascii art ([ee6f18d](https://github.com/albertoig/homelab/commit/ee6f18d9068267c2509e29417e451e20917fe97b))
* **helmfile:** add OpenBao and External Secrets Operator ([676ca95](https://github.com/albertoig/homelab/commit/676ca95abb4eaf5cb2d55698e076e67ac927d316))
* **helmfile:** add update-locks task to refresh all env lock files ([7e6ecc8](https://github.com/albertoig/homelab/commit/7e6ecc8838e727981172ea646a834ce035a75317))
* **helmfile:** add Velero backup with Cloudflare R2 ([8c791d1](https://github.com/albertoig/homelab/commit/8c791d1cfa59c920833dcf8e50362f692829291d))
* **install:** replace banner with hypercrush-style ASCII art header ([5bdea56](https://github.com/albertoig/homelab/commit/5bdea565b75a2b67b7ba0c4ce5119cf51f6ce6d3))
* **makefile:** add setup target for full environment bootstrap ([f21d4a2](https://github.com/albertoig/homelab/commit/f21d4a2985527ec34f182b19e8a6cf93d2cd1b33))
* **makefile:** run terraform apply/destroy alongside helmfile install/destroy ([5ed3ee9](https://github.com/albertoig/homelab/commit/5ed3ee9ea2d07a0b57eea4daf658313f04899357))
* **mise:** add clean task to remove build artifacts and caches ([af6821d](https://github.com/albertoig/homelab/commit/af6821de28bdfca2b84d9e92fed1e72c78082b58))
* **mise:** add mise for tool version management ([76c2778](https://github.com/albertoig/homelab/commit/76c2778f7bd4145feb8c9112ddd46a2710e1c693))
* **openbao:** add setup preflight and select environment via env.sh ([19ecd3f](https://github.com/albertoig/homelab/commit/19ecd3f527302d1d98470c0338acc11cc928bc59))
* **scripts:** add reusable environment selector lib ([6c26e98](https://github.com/albertoig/homelab/commit/6c26e9833ca3b5d7e31bfc5bd6d95b2063f75f24))
* **scripts:** add setup-openbao script for post-deploy init and ESO wiring ([8f42ead](https://github.com/albertoig/homelab/commit/8f42ead3c6455b726b3415ff26a126f00a0fadef))
* **scripts:** refactor init-secrets to use gum for interactive UX ([7a79dc0](https://github.com/albertoig/homelab/commit/7a79dc0ac9e3e8890a64fddbf4860013261527ab))
* **secrets:** add [@autogen](https://github.com/autogen) markers and auto-generation prompts in init-secrets ([151d00e](https://github.com/albertoig/homelab/commit/151d00ecabdc57e290fc374ad6bc71a54b0755fb))
* **secrets:** add openbao encrypted secrets for dev ([712ca6d](https://github.com/albertoig/homelab/commit/712ca6d7ff2518459240d0701d941126ca90877f))
* **terraform:** add Cloudflare R2 bucket for Velero backups ([628b5d2](https://github.com/albertoig/homelab/commit/628b5d27dacd264db3f5bfa00d943f04648ebe03))
* **terraform:** add Cloudflare R2 remote state backend via environment variables ([d6f52e2](https://github.com/albertoig/homelab/commit/d6f52e2d1176921a569cf95fe332067385a7dac5))
* **terraform:** scope R2 bucket and Terraform state per environment via workspaces ([d067015](https://github.com/albertoig/homelab/commit/d067015886aea41ddd5929f43ed76e7817e8c0c2))
* **tests:** add pytest smoke and k8s integration test scaffold ([4fff65e](https://github.com/albertoig/homelab/commit/4fff65e24a75d35fa02b8784e7bdc84b8be6055c))


### Performance Improvements

* **check:** drop decorative spinner delays from prerequisite checks ([116c408](https://github.com/albertoig/homelab/commit/116c4085c4322df84987fc64be796369d19ed745))

# 1.0.0 (2026-05-28)


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
