#!/usr/bin/env bash
# Shared OpenBao / External Secrets identifiers for homelab scripts.
# Source this file to get the constants the setup and preflight scripts share:
#   source "$SCRIPT_DIR/../lib/openbao.sh"
#
# These mirror the deployment defined in helmfile/releases/004-core-apps and
# helmfile/common/values/openbao.yaml.gotmpl — keep them in sync if that changes.

# ── OpenBao server ────────────────────────────────────────────────────────────

NAMESPACE="openbao-system"            # release namespace (004-core-apps)
POD="openbao-0"                       # standalone StatefulSet pod
BAO_ADDR="http://127.0.0.1:8200"      # in-pod API address
KV_PATH="secret"                      # KV v2 mount path

# ── External Secrets Operator / ClusterSecretStore ────────────────────────────

ESO_NAMESPACE="external-secrets-system"               # ESO release namespace
ESO_POLICY="eso-read"                                 # read-only OpenBao policy
ESO_SECRET="openbao-eso-token"                        # k8s secret holding the ESO token
CSS_NAME="openbao"                                    # ClusterSecretStore name
CSS_CRD="clustersecretstores.external-secrets.io"     # CRD the store needs

# ── OIDC auth method (Authentik SSO) ──────────────────────────────────────────

OIDC_PATH="oidc"                                      # auth method mount path
OIDC_ROLE="default"                                   # default OIDC role
# Authentik signs id_tokens with the shared ECDSA cert (ES256); OpenBao's OIDC
# method only accepts RS256 unless told otherwise.
OIDC_SIGNING_ALG="ES256"
# Client id/secret are rendered by the authentik-blueprints chart into this
# secret (keys OPENBAO_CLIENT_ID / OPENBAO_CLIENT_SECRET); see shared-sso.
OIDC_CRED_NS="auth-system"
OIDC_CRED_SECRET="authentik-initial-config-secrets"
# OIDC group → policy mapping. Members of the Authentik "OpenBao Admins" group
# (provisioned by authentik-blueprints) get the admin policy, which grants full
# access to the whole KV mount (downstream paths like homelab-apps/* may not
# exist when the base runs, so it is granted broadly over secret/*).
OIDC_ADMIN_GROUP="OpenBao Admins"
OIDC_ADMIN_POLICY="openbao-admins"
