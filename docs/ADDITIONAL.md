# Additional Setup

Supplementary configuration that may be needed depending on your environment.

## KubeContext names

> **Warning**: This file is part of the upstream repository. If you modify it and upstream updates it, you will get merge conflicts on fork sync.

Helmfile uses your Kubernetes context to connect to the right cluster. The environment definitions in `helmfile/environments.yaml.gotmpl` reference context names.

If your context names differ from `homelab-dev` and `homelab-prod`, update them:

```yaml
environments:
  dev:
    kubeContext: your-dev-context
  prod:
    kubeContext: your-prod-context
```

List your available contexts with:

```bash
kubectl config get-contexts
```

This will be automated in a future release.
