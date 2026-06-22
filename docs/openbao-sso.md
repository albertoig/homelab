# OpenBao login via Authentik (OIDC)

OpenBao authenticates against the base Authentik using OIDC — the same identity
provider Grafana and ArgoCD use. The Authentik side (an `openbao` OAuth2/OIDC
provider + application, and an `OpenBao Admins` group) is provisioned
declaratively by the `authentik-blueprints` chart. This page covers the OpenBao
side, which is configured once at runtime with the `bao` CLI.

Throughout, replace `ROOT_URL` with your `root_dns` (e.g. the value in
`helmfile/environments/<env>/config.yaml`).

## This is OIDC, not plain OAuth

OpenBao does not act as a generic OAuth2 client. It uses its native **`oidc`
auth method** — OpenID Connect, the identity layer built on top of OAuth 2.0 —
so OpenBao is an OIDC *relying party*. Authentik's provider model is named
`oauth2provider`, but Authentik labels it the **"OAuth2/OpenID Provider"**: the
same object is the OIDC provider and publishes a discovery document per
application at `https://auth.ROOT_URL/application/o/openbao/.well-known/openid-configuration`.

The flow:

```
  bao login -method=oidc  (or the Web UI)
        │  browser → Authentik authorize/login (+ MFA)
        ▼
  Authentik OIDC provider  ── id_token ──►  OpenBao oidc auth method
        ▲                                        │ validates against the
        └──────── oidc_discovery_url ────────────┘ issuer's jwks, maps a role
```

`auth/oidc/config`'s `oidc_discovery_url` is exactly that issuer
(`https://auth.ROOT_URL/application/o/openbao/`); OpenBao reads the discovery
doc and drives the standard OIDC authorization-code flow. (The same auth method
also has a non-interactive `jwt` mode for machine logins.)

## Prerequisites

1. `sso.openbao.client_id` / `sso.openbao.client_secret` are set in the
   `shared-sso` secret and the base is deployed, so Authentik has the `openbao`
   provider. Generate them with `openssl rand -hex 16` / `openssl rand -hex 32`.
2. OpenBao is reachable, initialized and unsealed at
   `https://openbao.internal.ROOT_URL`.
3. You can log in with a privileged token to configure the auth method.

## One-time: enable the OIDC auth method

```bash
export BAO_ADDR="https://openbao.internal.ROOT_URL"
bao login                       # with an admin/root token

bao auth enable oidc

bao write auth/oidc/config \
  oidc_discovery_url="https://auth.ROOT_URL/application/o/openbao/" \
  oidc_client_id="<OPENBAO_CLIENT_ID>" \
  oidc_client_secret="<OPENBAO_CLIENT_SECRET>" \
  default_role="default"

bao write auth/oidc/role/default \
  user_claim="sub" \
  allowed_redirect_uris="https://openbao.internal.ROOT_URL/ui/vault/auth/oidc/oidc/callback,http://localhost:8250/oidc/callback" \
  token_policies="default" \
  oidc_scopes="openid,profile,email"
```

- `oidc_discovery_url` is the per-application issuer Authentik exposes (the
  `openbao` provider uses `issuer_mode: per_provider`); OpenBao appends
  `/.well-known/openid-configuration` itself.
- `oidc_client_id` / `oidc_client_secret` are the values from the `shared-sso`
  secret.
- The two `allowed_redirect_uris` match the redirect URIs declared on the
  Authentik provider: the web UI and the CLI helper (port 8250).

## Logging in

You log in with your **Authentik** account, not an OpenBao-local user — OpenBao
hands you off to Authentik. Use the homelab SSO admin created by the blueprint
(`sso.admin.*`); TOTP MFA is enforced, so the first login walks you through
setting up an authenticator app.

Find the SSO admin username/password (they live in the `shared-sso` secret):

```bash
# from the encrypted secret
sops --decrypt helmfile/environments/<env>/secrets/shared-sso.enc.yaml | yq '.sso.admin'

# …or from the live cluster secret
kubectl -n auth-system get secret authentik-initial-config-secrets \
  -o jsonpath='{.data.HOMELAB_ADMIN_USERNAME}' | base64 -d; echo
kubectl -n auth-system get secret authentik-initial-config-secrets \
  -o jsonpath='{.data.HOMELAB_ADMIN_PASSWORD}' | base64 -d; echo
```

**Web UI** — browse to `https://openbao.internal.ROOT_URL`, pick the **OIDC**
method, and sign in through Authentik.

**CLI** — opens a browser to complete the Authentik flow:

```bash
export BAO_ADDR="https://openbao.internal.ROOT_URL"
bao login -method=oidc
```

## Optional: map the "OpenBao Admins" group to a policy

To grant admins more than the `default` policy based on their Authentik group,
include the groups claim and map it on the role:

```bash
bao write auth/oidc/role/default \
  user_claim="sub" \
  groups_claim="groups" \
  allowed_redirect_uris="https://openbao.internal.ROOT_URL/ui/vault/auth/oidc/oidc/callback,http://localhost:8250/oidc/callback" \
  token_policies="default" \
  oidc_scopes="openid,profile,email"

# Bind the Authentik "OpenBao Admins" group to an OpenBao policy (e.g. admin):
bao write identity/group name="OpenBao Admins" type="external" \
  policies="admin" \
  member_group_ids=""   # filled by the group-alias below

# Create a group alias linking the OIDC group name to the external group.
# (Look up the accessor with: bao auth list -format=json | jq -r '."oidc/".accessor")
bao write identity/group-alias name="OpenBao Admins" \
  mount_accessor="<oidc-accessor>" \
  canonical_id="<external-group-id>"
```
