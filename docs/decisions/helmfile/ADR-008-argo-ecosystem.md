# ADR-008: Adopt the Argo ecosystem for CI and progressive delivery

- **Date**: 2026-06-27
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: infrastructure

## Context

The platform already runs **Argo CD** (`gitops-system`) for continuous *delivery*.
Argo CD reconciles desired state, but it does not build images, run tests/lint,
react to Git activity, or roll out workloads progressively. Three gaps remain:

- **In-cluster CI** — an engine that runs container-native pipelines
  (build → test → lint → push) on our own nodes, with secrets from OpenBao.
- **Event-driven triggering** — turning a Git webhook (push / PR) into a run.
- **Progressive delivery** — canary / blue-green with analysis-based
  automatic promotion and rollback, which Argo CD's straight reconcile lacks.

Issue #20 proposed Tekton for the CI piece. Tekton's only supported install path
is an Operator that reconciles a singleton `TektonConfig` CR, which forces
hand-patched vendored manifests and Helm ownership-adoption workarounds — breaking
the clean **upstream chart + thin config chart** convention every other component
in this repo follows (`cert-manager` + `cert-manager-config`, `metallb` +
`metallb-config`). #20 is superseded by this decision.

## Decision

Adopt the rest of the **Argo ecosystem**, installed from the official upstream
`argoproj/argo-helm` charts (already wired as the `argocd` Helm repo), each paired
with a thin local config chart, via helmfile (`004-core-apps`):

- **Argo Workflows** (`ci-system`) — the CI/pipeline engine, plus
  `argo-workflows-config` for the SSO → ServiceAccount RBAC mapping.
- **Argo Events** (`ci-system`, co-located with Workflows as the CI trigger layer) —
  `argo-events-config` provisions the default EventBus and the workflow-submission
  RBAC as ready-to-use building blocks.
- **Argo Rollouts** (`rollouts-system`) — the controller only; real
  `Rollout`/`AnalysisTemplate` resources ship with the application repos they belong to.

The config charts deliberately ship **no demo workloads** (no sample
WorkflowTemplate/Workflow, no webhook EventSource/Sensor, no sample Rollout) — only
the real, reusable platform configuration. A paused sample canary in particular
never reaches a Ready state, which would stall a `helmfile` deploy.

Supporting decisions:

- **SSO = native OIDC**, not oauth2-proxy. The Argo Workflows server has a built-in
  SSO mode; it authenticates directly against Authentik exactly like Argo CD and
  Grafana do (an `oauth2provider` + `application` in the Authentik blueprint, client
  credentials from the shared-sso SOPS secret). The issue's literal "oauth2-proxy"
  wording is superseded — no forward-auth proxy exists in the repo and none is
  introduced. Workflows RBAC maps the Authentik **Argo Admins** group to a
  ServiceAccount via the `workflows.argoproj.io/rbac-rule` annotation.
- **Argo CD integration = health only.** These components are installed via helmfile
  like everything else; the repo has no Argo CD `Application`/app-of-apps pattern and
  this change does not introduce one. We only add a Lua **resource health** check for
  `argoproj.io/Rollout` to Argo CD so a paused/degraded canary surfaces correctly.
- **CRDs ship with each chart** (`crds.install` / `installCRDs`), matching the
  `cert-manager` pattern — no separate `001-crds` entry, no vendored manifests.

## Alternatives considered

- **Tekton (#20)** — rejected: operator + singleton CR breaks repo conventions.
- **oauth2-proxy in front of the Workflows UI** — rejected: adds a new auth pattern
  for no benefit when the server speaks OIDC natively.
- **Argo CD Applications (app-of-apps) for these components** — deferred: it would
  introduce a brand-new architectural pattern; out of scope for this iteration.

## Consequences

- One consistent toolchain (Argo CD + Workflows + Events + Rollouts), one SSO
  pattern, one operating model.
- **Artifact repository (MinIO / S3)** is a known dependency for Workflows artifact
  passing and is **not** included here — tracked as follow-up #26.
- A real Git-webhook-triggered build/test/push pipeline (kaniko/buildkit) and
  supply-chain provenance (cosign / in-toto) are follow-ups (#28), not platform
  components — they bring their own EventSource/Sensor/WorkflowTemplate.
- The Rollouts dashboard has no native OIDC; it is left internal-only
  (`kubectl argo rollouts dashboard` / port-forward) until a gating story exists.
