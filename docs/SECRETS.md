# Secrets Reference

Complete reference for all per-chart secrets used in this homelab. Each chart's secrets are stored in `helmfile/environments/<env>/secrets/<chart>.enc.yaml` (SOPS-encrypted) and loaded automatically by helmfile.

## How secrets work

```
helmfile/secret-templates/<chart>.template.yaml   (templates with descriptions)
        │
        ▼  ./scripts/init-secrets.sh <env>   (interactive prompts)
helmfile/environments/<env>/secrets/<chart>.secrets.yaml   (plaintext, gitignored)
        │
        ▼  ./scripts/sops-encrypt-secrets.sh <env>   (or auto-encrypted by init)
helmfile/environments/<env>/secrets/<chart>.enc.yaml   (encrypted, committed)
        │
        ▼  helmfile merges per-chart secrets into each release's values
Kubernetes Secrets / Helm values
```

Only charts that actually need secrets have template files. Charts without secrets (longhorn, metallb, loki, alloy, tempo, pyroscope, traefik, argocd) use `common_values_only` and skip the secrets step entirely via `missingFileHandler: Warn`.

Shared credentials that span multiple charts use the `shared-sso.enc.yaml` file, loaded alongside per-chart secrets via the `values_gotmpl_secrets_and_shared` inherit template.

---

## Shared SSO

**File:** `shared-sso.enc.yaml`
**Used by:** `authentik` and `grafana` releases (via `values_gotmpl_secrets_and_shared` template)
**Criticality:** High — breaks SSO for all integrated applications

| Key | Criticality | Description |
|-----|-------------|-------------|
| `sso.grafana.client_id` | **High** | OAuth2 client ID for Grafana SSO. Single source of truth — both Authentik (via worker env vars / blueprint `!Env`) and Grafana (via env vars) read from here. |
| `sso.grafana.client_secret` | **High** | OAuth2 client secret for Grafana SSO. |

**If wrong:** SSO login fails with `invalid_client` error. Both Authentik and Grafana read these same values, so there's no risk of mismatch as long as this single file is correct.

**How to obtain:**
```bash
openssl rand -hex 16   # client_id
openssl rand -hex 32   # client_secret
```

---

## Grafana

**File:** `grafana.enc.yaml`
**Chart:** `grafana-community/grafana`
**Criticality:** High — blocks dashboard access

| Key | Criticality | Description |
|-----|-------------|-------------|
| `adminPassword` | **High** | Emergency admin password for local Grafana access. Only used when `disable_login_form` is temporarily re-enabled. Normal access uses Authentik SSO. |

**How to obtain:**
```bash
openssl rand -base64 24  # adminPassword (emergency use)
```

---

## Authentik

**File:** `authentik.enc.yaml`
**Chart:** `authentik/authentik`
**Criticality:** Critical — multiple secrets, any wrong value breaks the identity provider

| Key | Criticality | Description |
|-----|-------------|-------------|
| `authentik.secret_key` | **Critical** | Master cryptographic key used for signing sessions, tokens, cookies, and encrypting internal data. Must remain stable across restarts. |
| `authentik.email.from` | Low | Sender address shown on outbound emails (password resets, enrollments, notifications). Example: `"Homelab <homelab@iglesias.cloud>"`. |
| `authentik.email.password` | **Medium** | SMTP authentication password. If wrong, Authentik cannot send any emails. |
| `authentik.email.host` | **Medium** | SMTP server hostname (e.g., `smtp.protonmail.ch`, `smtp.gmail.com`). |
| `authentik.email.username` | **Medium** | SMTP authentication username, typically the same as the sender email. |
| `authentik.postgresql.password` | **Critical** | Password for Authentik's PostgreSQL database user. If wrong, Authentik cannot connect to its database and crash-loops. |
| `postgresql.auth.password` | **Critical** | PostgreSQL superuser (`postgres`) password for the bundled PostgreSQL instance. If wrong, the database pod fails to initialize. |
| `authentik.admin.email` | **High** | Admin user email created in Authentik via blueprint. Used to log in to Grafana via SSO. |
| `authentik.admin.password` | **High** | Admin user password created in Authentik via blueprint. |

**If `secret_key` is wrong/changed:** Authentik may fail to start, or all existing sessions and tokens are invalidated on restart.

**If email secrets are wrong:** Password resets, enrollment invitations, and notifications silently fail. Users cannot self-service recover accounts.

**If PostgreSQL secrets are wrong:** Authentik pod enters CrashLoopBackOff. Database connection refused errors in logs.

**If `admin.email`/`admin.password` are wrong:** The blueprint-created admin user cannot log in to Authentik or Grafana via SSO.

**How to obtain:**
- `authentik.secret_key`: `openssl rand -hex 32`
- `authentik.email.*`: Your SMTP provider credentials (ProtonMail, Gmail app password, SendGrid API key, etc.)
- `authentik.postgresql.password`: `openssl rand -base64 24`
- `postgresql.auth.password`: `openssl rand -base64 24`
- `authentik.admin.email`: Your admin email address
- `authentik.admin.password`: Strong password for the admin user

---

## Prometheus Stack

**File:** `prometheus-stack.enc.yaml`
**Chart:** `prometheus-community/kube-prometheus-stack`
**Criticality:** Medium — breaks alerting but monitoring still works

| Key | Criticality | Description |
|-----|-------------|-------------|
| `alertmanagerSlackWebhook` | **Medium** | Slack incoming webhook URL used by Alertmanager to deliver alert notifications to a Slack channel. |

**If wrong:** Alertmanager cannot deliver Slack notifications. Alerts are silently dropped unless other receivers (email, PagerDuty, etc.) are configured. Prometheus metrics collection and Grafana dashboards continue to work normally.

**How to obtain:**
1. Go to [Slack API: Incoming Webhooks](https://api.slack.com/messaging/webhooks)
2. Create a webhook for the desired channel
3. Copy the webhook URL (format: `https://hooks.slack.com/services/T.../B.../xxx`)

---

## Cert-Manager Config

**File:** `cert-manager-config.enc.yaml`
**Chart:** `charts/cert-manager-config` (local chart)
**Criticality:** Critical — breaks TLS certificate issuance and DNS management

This is the most complex secrets file. It powers two charts: the local `cert-manager-config` chart and the `external-dns` chart. The `secret.apiKey` value creates a Kubernetes Secret (`cloudflare-api-key`) that is shared by both cert-manager's ClusterIssuer (for DNS-01 ACME challenges) and external-dns (for DNS record management).

| Key | Criticality | Description |
|-----|-------------|-------------|
| `secret.apiKey` | **Critical** | Cloudflare API token with `Zone:DNS:Edit` and `Zone:Zone:Read` permissions. Stored in the `cloudflare-api-key` Kubernetes Secret and consumed by both cert-manager and external-dns. |
| `secret.email` | **High** | Cloudflare account email address. Stored alongside the API token in the Kubernetes Secret. |
| `clusterIssuer.email` | **Critical** | Email registered with Let's Encrypt for the ACME account. Used for certificate expiration warnings and account recovery. Required by the ACME protocol. |
| `clusterIssuer.cloudflare.email` | Low | Cloudflare account email in the ClusterIssuer's DNS-01 solver config. Optional — token-only auth is preferred. |
| `certificate.dnsNames` | **High** | List of domain names for the TLS certificate (Subject Alternative Names). Example: `["internal.iglesias.cloud"]`. |

**If `secret.apiKey` is wrong:** TLS certificates cannot be issued (DNS-01 challenge fails with Cloudflare API errors). External-dns cannot create or update DNS records. Check cert-manager logs: `kubectl logs -n cert-manager-system deploy/cert-manager`.

**If `clusterIssuer.email` is wrong:** Let's Encrypt rejects the ACME registration. No certificates can be issued until a valid email is provided.

**If `certificate.dnsNames` is wrong:** Certificate is issued for the wrong domain(s). Browsers show certificate mismatch errors.

**Cross-chart usage:** The `cloudflare-api-key` Kubernetes Secret created by `cert-manager-config` is also consumed by `external-dns` via `env[0].valueFrom.secretKeyRef` in `common/values/external-dns.yaml.gotmpl`. This is why `external-dns` has `needs: cert-manager-system/cert-manager-config`.

**How to obtain:**
- `secret.apiKey`: Create a Cloudflare API token at https://dash.cloudflare.com/profile/api-tokens with permissions:
  - `Zone:DNS:Edit` for your zone
  - `Zone:Zone:Read` for your zone
- `secret.email`: Your Cloudflare account email
- `clusterIssuer.email`: Any email you control (used by Let's Encrypt for expiration warnings)
- `certificate.dnsNames`: Your domain(s) (e.g., `["internal.iglesias.cloud"]`)

---

## Quick reference

| Chart | Secret file | Key | Criticality | Impact if wrong |
|-------|------------|-----|-------------|-----------------|
| shared | `shared-sso.enc.yaml` | `sso.grafana.client_id` | High | SSO login fails (invalid_client) |
| shared | `shared-sso.enc.yaml` | `sso.grafana.client_secret` | High | SSO login fails (invalid_client) |
| grafana | `grafana.enc.yaml` | `adminPassword` | High | Cannot log in via local auth (emergency only) |
| authentik | `authentik.enc.yaml` | `authentik.secret_key` | Critical | Identity provider fails to start |
| authentik | `authentik.enc.yaml` | `authentik.email.from` | Low | Emails show wrong sender |
| authentik | `authentik.enc.yaml` | `authentik.email.password` | Medium | Email sending fails |
| authentik | `authentik.enc.yaml` | `authentik.email.host` | Medium | Email sending fails |
| authentik | `authentik.enc.yaml` | `authentik.email.username` | Medium | SMTP auth fails |
| authentik | `authentik.enc.yaml` | `authentik.postgresql.password` | Critical | Database connection fails |
| authentik | `authentik.enc.yaml` | `postgresql.auth.password` | Critical | Database init fails |
| authentik | `authentik.enc.yaml` | `authentik.admin.email` | High | No admin user in Authentik |
| authentik | `authentik.enc.yaml` | `authentik.admin.password` | High | Admin cannot log in |
| prometheus-stack | `prometheus-stack.enc.yaml` | `alertmanagerSlackWebhook` | Medium | Alerts not delivered to Slack |
| cert-manager-config | `cert-manager-config.enc.yaml` | `secret.apiKey` | Critical | TLS + DNS management breaks |
| cert-manager-config | `cert-manager-config.enc.yaml` | `secret.email` | High | Cloudflare API auth issues |
| cert-manager-config | `cert-manager-config.enc.yaml` | `clusterIssuer.email` | Critical | Let's Encrypt rejects registration |
| cert-manager-config | `cert-manager-config.enc.yaml` | `clusterIssuer.cloudflare.email` | Low | Optional Cloudflare email |
| cert-manager-config | `cert-manager-config.enc.yaml` | `certificate.dnsNames` | High | Certificate for wrong domains |

## Related

- **Initialize secrets:** `./scripts/init-secrets.sh <environment>` — interactive prompts from templates
- **Encrypt:** `./scripts/sops-encrypt-secrets.sh <environment> [chart]`
- **Decrypt:** `./scripts/sops-decrypt-secrets.sh <environment> [chart]`
- **Templates:** `helmfile/secret-templates/*.template.yaml` — source of truth for secret keys and descriptions
