# ADR-006: Split Helmfile Into Staged Files to Avoid Chicken-and-Egg Dependencies

- **Date**: 2026-04-01
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: infrastructure

## Context

The root `helmfile.yaml.gotmpl` includes all releases together:

```yaml
bases:
- helmfile/templates.yaml.gotmpl
- helmfile/environments.yaml.gotmpl
- helmfile/repositories.yaml
- helmfile/common/common.yaml.gotmpl          # common applications (Longhorn, MetalLB, Prometheus, Grafana, Loki, Alloy, Tempo, Pyroscope, Traefik, Authentik, ArgoCD)
- helmfile/environments/{{ .Environment.Name }}/{{ .Environment.Name }}.yaml

helmfiles:
- path: helmfile/001-crds.helmfile.yaml       # CRDs
- path: helmfile/002-certs.helmfile.yaml.gotmpl  # cert-manager, cert-manager-config, external-dns
- path: helmfile/003-ingresses.helmfile.yaml.gotmpl  # Ingress resources
```

`common.yaml.gotmpl` defines the core homelab stack — Longhorn, MetalLB, Prometheus, Grafana, Loki, Alloy, Tempo, Pyroscope, Traefik, Authentik, ArgoCD — with `needs:` constraints between them (e.g., prometheus-stack needs Longhorn, Grafana needs prometheus-stack, ArgoCD needs Traefik).

Running everything in a single `helmfile apply` created chicken-and-egg dependency failures:

1. **CRDs vs. common applications**: `prometheus-operator-crds` must be fully registered in the API server before `prometheus-stack` (from `common.yaml.gotmpl`) can create `ServiceMonitor`, `PrometheusRule`, and other custom resources. Helmfile's `needs` ensures release ordering within a state, but CRD registration is asynchronous — the API server must accept the new resource type before any release can use it. Helmfile cannot express this "wait for API server to register CRDs" prerequisite.

2. **cert-manager vs. common applications**: `cert-manager-config` creates `Certificate` and `ClusterIssuer` resources that depend on the cert-manager webhook being ready. If cert-manager and the common applications run in the same state, the common stack (which depends on TLS certificates for its Ingresses) races against certificate issuance.

3. **cert-manager-config vs. Ingresses (003)**: Ingress resources reference TLS secrets provisioned by certificates. If Ingresses are deployed before certificates are issued, TLS termination fails.

4. **common applications vs. Ingresses**: The common applications in `common.yaml.gotmpl` (Traefik, Authentik, ArgoCD) need their Ingress resources to have valid TLS, which requires cert-manager to be running and certificates to be issued. All of this must happen before `003-ingresses.helmfile.yaml.gotmpl` creates Ingress resources.

The core issue: helmfile resolves dependencies within a single state but cannot handle the multi-step "install → wait → verify → proceed" pattern needed for CRD propagation, certificate issuance, and Ingress creation. The `common.yaml.gotmpl` applications are the bulk of the homelab stack and must run after CRDs and certs are ready but before Ingresses are created.

## Decision

Split the deployment into four sequentially-executed stages using `helmfiles:` in the root `helmfile.yaml.gotmpl`:

1. `helmfile/001-crds.helmfile.yaml` — CRDs (prometheus-operator-crds)
2. `helmfile/002-certs.helmfile.yaml.gotmpl` — cert-manager, cert-manager-config, external-dns
3. `helmfile/common/common.yaml.gotmpl` — common applications (Longhorn, MetalLB, Prometheus, Grafana, Loki, Alloy, Tempo, Pyroscope, Traefik, Authentik, ArgoCD)
4. `helmfile/003-ingresses.helmfile.yaml.gotmpl` — Ingress resources

The root `helmfile.yaml.gotmpl` defines the execution order via `helmfiles:`. Each staged file has its own lock file (or uses the environment lock file for common applications). The staged files ensure each phase completes before the next begins.

## Alternatives Considered

### Option A: Single file with needs and hooks (status quo)
- **Description**: Keep one `helmfile.yaml`, use `needs` for ordering and `prepare`/`cleanup` hooks to wait for readiness.
- **Pros**:
  - Single file to manage.
  - Helmfile handles everything in one run.
- **Cons**:
  - Hooks add complexity and are not idiomatic for CRD propagation.
  - `needs` ensures release ordering but not "CRDs accepted by API server" or "certificate issued" readiness.
  - Race conditions remain: helmfile may proceed to the next release before the previous one's side effects (CRD registration, certificate issuance) are complete.
  - Hard to debug when a release fails due to a prerequisite not being ready.

### Option B: Staged helmfiles via helmfiles: directive (Selected)
- **Description**: Use helmfile's `helmfiles:` directive to run CRDs, certs, common applications, and Ingresses in sequence. Each staged file is a self-contained helmfile state.
- **Pros**:
  - Explicit ordering: each stage completes before the next starts.
  - CRDs are fully registered before cert-manager tries to create Certificate resources.
  - Certificates are issued before common applications and Ingresses need TLS.
  - Clear failure boundaries: if CRDs fail, the deployment stops — no partial state.
  - `common.yaml.gotmpl` remains the single source of truth for common application releases.
- **Cons**:
  - Shared config (repositories, environments, templates) must be referenced via `bases:` in each staged file.
  - Adding a new release requires deciding which stage it belongs to.

### Option C: Separate helmfile releases with long waits
- **Description**: Single file with `wait: true` and `waitForJobs: true` on critical releases, plus extended timeouts.
- **Pros**:
  - Single file.
  - Native helmfile mechanisms.
- **Cons**:
  - Timeouts are arbitrary: CRD propagation and certificate issuance have no guaranteed upper bound.
  - Wastes time waiting when failures are immediate (e.g., invalid CRD).
  - Still cannot express "wait for CRD to be accepted by API server" or "wait for certificate to be issued".

### Option D: Separate helmfile + Kubernetes Jobs for readiness gates
- **Description**: Single file with Kubernetes Jobs that block until CRDs are registered or certificates are issued.
- **Pros**:
  - Single file.
  - Precise readiness checks.
- **Cons**:
  - Significant complexity: custom Jobs, RBAC, cleanup logic.
  - Jobs are heavyweight for what is essentially a sequencing problem.
  - Hard to maintain and debug.

## Consequences

### Positive
- **No chicken-and-egg failures**: CRDs are fully registered before any release tries to use them.
- **Certificates are issued before Ingresses**: TLS secrets exist before Ingress resources reference them.
- **Clear failure stages**: If CRDs fail, the deployment stops — no partial state with orphaned cert-manager resources.
- **Independent lock files**: Each stage has its own `helmfile.lock`, allowing independent dependency updates.
- **common.yaml.gotmpl as single source of truth**: All common application releases remain in one file, not split across multiple staged files.

### Negative
- **Multiple files to maintain**: Shared configuration (repositories, environments, templates) is repeated via `bases:` in each staged file.
- **Multi-step deployment**: The root `helmfile.yaml.gotmpl` orchestrates the stages via `helmfiles:`, but if run individually, each stage must be executed in order.
- **Ordering rigidity**: Adding a new release requires deciding which stage it belongs to.

### Risks
- **Risk**: A contributor adds a release to the wrong stage file, breaking the ordering contract.
  - **Mitigation**: File naming convention (`001-`, `002-`, common, `003-`) makes the intended order explicit. Comments at the top of each file describe what belongs in that stage.

## References

- `helmfile.yaml.gotmpl` — root entry point, orchestrates stages via `helmfiles:`
- `helmfile/001-crds.helmfile.yaml` — CRD releases
- `helmfile/002-certs.helmfile.yaml.gotmpl` — cert-manager and DNS releases
- `helmfile/common/common.yaml.gotmpl` — common application releases (Longhorn, MetalLB, Prometheus, Grafana, Loki, Alloy, Tempo, Pyroscope, Traefik, Authentik, ArgoCD)
- `helmfile/003-ingresses.helmfile.yaml.gotmpl` — Ingress releases
