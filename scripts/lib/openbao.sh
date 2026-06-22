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
# Client id/secret are rendered by the authentik-blueprints chart into this
# secret (keys OPENBAO_CLIENT_ID / OPENBAO_CLIENT_SECRET); see shared-sso.
OIDC_CRED_NS="auth-system"
OIDC_CRED_SECRET="authentik-initial-config-secrets"
