# OpenBao login via Authentik (OIDC)

OpenBao authenticates against the base Authentik using OIDC — the same identity
provider Grafana and ArgoCD use. The Authentik side (an `openbao` OAuth2/OIDC
provider + application, and an `OpenBao Admins` group) is provisioned
declaratively by the `authentik-blueprints` chart. This page covers the OpenBao
side, which is configured once at runtime with the `bao` CLI.

Throughout, replace `ROOT_URL` with your `root_dns` (e.g. the value in
`helmfile/environments/<env>/config.yaml`).

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
