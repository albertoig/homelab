# tekton-operator

Vendored install manifests for the [Tekton Operator](https://github.com/tektoncd/operator),
pinned to a specific upstream release. The operator watches a `TektonConfig`
custom resource and reconciles it into the actual Tekton components (Pipelines,
Triggers, Dashboard, Chains). The `TektonConfig` itself lives in the sibling
`tekton-config` chart.

## How it works

- `files/release.yaml` is the upstream Kubernetes release manifest with the
  `Namespace` document removed (helmfile's `createNamespace: true` owns the
  `tekton-operator` namespace, matching the rest of this repo).
- `templates/operator.yaml` emits that file verbatim via `.Files.Get`, so the
  upstream YAML is applied as-is without Go-template evaluation.

## Upgrading

1. Pick the new version from https://github.com/tektoncd/operator/releases.
2. Re-vendor and strip the Namespace doc:
   ```sh
   V=v0.81.0   # example
   curl -fsSL -o charts/tekton-operator/files/release.yaml \
     https://github.com/tektoncd/operator/releases/download/$V/release.yaml
   yq eval -i 'select(.kind != "Namespace")' charts/tekton-operator/files/release.yaml
   ```
3. Bump `version` and `appVersion` in `Chart.yaml`.
4. `helmfile -e <env> -l app=cicd diff` and review CRD/RBAC changes before apply.
