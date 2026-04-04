# Plan: Refactor Authentik Blueprints Secret Handling

## Problem

The authentik blueprint (`charts/authentik-blueprints/templates/grafana-blueprint.yaml`) receives sensitive credentials (client ID/secret, admin email/password) via `!Env` directives, which reads them from environment variables injected into the authentik worker pod. Issues:

1. **Env vars expose secrets** in pod spec (`kubectl describe pod`), helmfile diff output
2. **Naming confusion**: `GRAFANA_ADMIN_*` misleading — these are homelab-wide admin creds
3. **No deployment isolation**: Blueprints and authentik are in the same helmfile release file
4. **Missing secrets**: `authentik.admin.email` and `authentik.admin.password` aren't in any sops file

## Solution

### 1. Create `helmfile/releases/002-blueprints.helmfile.yaml.gotmpl`

Extract `authentik-blueprints` from `003-core-apps` into its own helmfile (same pattern as `001-crds`).

```yaml
bases:
- ./../templates.yaml.gotmpl
- ./../repositories.yaml
- ./../environments/{{ .Environment.Name }}/{{ .Environment.Name }}.yaml

---

lockFilePath: ./../locks/{{ .Environment.Name }}/002-blueprints.helmfile.lock

---

releases:
  - name: authentik-blueprints
    namespace: auth-system
    createNamespace: true
    chart: ./../../charts/authentik-blueprints
    version: "0.1.0"
    wait: true
    missingFileHandler: Warn
    labels:
      app: identity
    inherit:
    - template: values_gotmpl_secrets_and_shared
```

Uses `values_gotmpl_secrets_and_shared` so it gets access to `sso.*` and `authentik.*` secret values.

### 2. Remove `authentik-blueprints` from `003-core-apps.helmfile.yaml.gotmpl`

- Delete the `authentik-blueprints` release block (lines 224-234)
- Remove `auth-system/authentik-blueprints` from authentik's `needs` list

### 3. Create `charts/authentik-blueprints/templates/grafana-sso-secret.yaml`

Kubernetes Secret containing all sensitive values for the blueprint to read via `!File`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-sso-credentials
  namespace: auth-system
type: Opaque
stringData:
  GRAFANA_CLIENT_ID: "{{ .Values.sso.grafana.client_id }}"
  GRAFANA_CLIENT_SECRET: "{{ .Values.sso.grafana.client_secret }}"
  HOMELAB_ADMIN_EMAIL: "{{ .Values.authentik.admin.email }}"
  HOMELAB_ADMIN_PASSWORD: "{{ .Values.authentik.admin.password }}"
```

### 4. Update blueprint to use `!File` instead of `!Env`

In `charts/authentik-blueprints/templates/grafana-blueprint.yaml`:

| Before | After |
|--------|-------|
| `!Env GRAFANA_CLIENT_ID` | `!File /etc/authentik/secrets/GRAFANA_CLIENT_ID` |
| `!Env GRAFANA_CLIENT_SECRET` | `!File /etc/authentik/secrets/GRAFANA_CLIENT_SECRET` |
| `!Env GRAFANA_ADMIN_EMAIL` | `!File /etc/authentik/secrets/HOMELAB_ADMIN_EMAIL` |
| `!Env GRAFANA_ADMIN_PASSWORD` | `!File /etc/authentik/secrets/HOMELAB_ADMIN_PASSWORD` |

### 5. Update `helmfile/common/values/authentik.yaml.gotmpl`

Replace the `worker.env` block with volume mount configuration:

**Remove:**
```yaml
worker:
  env:
    - name: GRAFANA_CLIENT_ID
      value: "{{ .Values.sso.grafana.client_id }}"
    - name: GRAFANA_CLIENT_SECRET
      value: "{{ .Values.sso.grafana.client_secret }}"
    - name: GRAFANA_ADMIN_EMAIL
      value: "{{ .Values.authentik.admin.email }}"
    - name: GRAFANA_ADMIN_PASSWORD
      value: "{{ .Values.authentik.admin.password }}"
```

**Add:**
```yaml
worker:
  volumeMounts:
    - name: grafana-sso-credentials
      mountPath: /etc/authentik/secrets
      readOnly: true
  volumes:
    - name: grafana-sso-credentials
      secret:
        secretName: grafana-sso-credentials
```

### 6. Add admin credentials to sops files

Add `authentik.admin.email` and `authentik.admin.password` to:
- `helmfile/environments/dev/secrets/authentik.enc.yaml`
- `helmfile/environments/prod/secrets/authentik.enc.yaml`

User will add these via `sops` manually (values are environment-specific).

## Files Modified

| File | Action |
|------|--------|
| `helmfile/releases/002-blueprints.helmfile.yaml.gotmpl` | **Create** |
| `helmfile/releases/003-core-apps.helmfile.yaml.gotmpl` | Remove authentik-blueprints release |
| `charts/authentik-blueprints/templates/grafana-sso-secret.yaml` | **Create** |
| `charts/authentik-blueprints/templates/grafana-blueprint.yaml` | `!Env` → `!File` |
| `helmfile/common/values/authentik.yaml.gotmpl` | env → volumeMount/volumes |
| `helmfile/environments/dev/secrets/authentik.enc.yaml` | Add admin credentials |
| `helmfile/environments/prod/secrets/authentik.enc.yaml` | Add admin credentials |

## Verification

1. `helmfile -e dev template -l name=authentik-blueprints` — verify secret renders correctly
2. `helmfile -e dev template -l name=authentik` — verify worker has volumeMounts, no env vars
3. `helmfile -e dev sync` — deploy and verify authentik worker can read secrets from files
4. Check Grafana SSO login works end-to-end
