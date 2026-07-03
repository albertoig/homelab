#!/usr/bin/env bash
# Shared helmfile helpers for single-release tooling.
# Source after lib/colors.sh. Requires: helmfile, helm, jq, yq.
#
# Public API (consumed by scripts/helm/destroy-one.sh, and reusable by the
# sibling install-one feature, #29):
#   helmfile_defined_releases <env>     -> JSON array of releases the Helmfile defines
#   helmfile_kube_context <env>         -> the kubeContext the Helmfile declares for <env>
#   helmfile_cluster_releases           -> JSON array of releases helm reports installed
#                                          (honours HELMFILE_KUBE_CONTEXT if set)
#   helmfile_defined_keys <env>         -> "namespace/name" per defined release (one/line)
#   helmfile_selectable_releases <env>  -> "namespace/name" per defined AND deployed release
#   helmfile_release_meta <env> <key>   -> "<chart>\t<version>" for a defined release
#   helmfile_dependents <env> <key>     -> "namespace/name" per release whose needs: hits <key>
#
# The guiding rule for every selector here is: THE YAML IS THE SOURCE OF TRUTH.
# A release is only ever "selectable" when it is BOTH defined in the Helmfile for
# the environment AND currently present in the cluster. Anything running in the
# cluster that the Helmfile does not define stays invisible to these helpers, so
# callers can never act on unmanaged releases.

HELMFILE_ROOT="${HELMFILE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HELMFILE_MAIN="$HELMFILE_ROOT/helmfile.yaml.gotmpl"

# Internal: key a release as "namespace/name", defaulting an empty namespace to
# "default" so it lines up with how helm reports installed releases.
_hf_jq_key='((if (.namespace // "") == "" then "default" else .namespace end) + "/" + .name)'

helmfile_defined_releases() {
    local env="$1"
    helmfile -f "$HELMFILE_MAIN" -e "$env" list --output json 2>/dev/null
}

# The kube context the Helmfile declares for an environment (first YAML document's
# environments.<env>.kubeContext). Empty when unknown. Used so the cluster
# cross-check targets the SAME context helmfile would sync/destroy against, not
# whatever context happens to be active (issue #35).
helmfile_kube_context() {
    local env="$1"
    yq -r "select(document_index == 0).environments.\"$env\".kubeContext // \"\"" \
        "$HELMFILE_MAIN" 2>/dev/null
}

# Cross-check the cluster using the target environment's context when the caller
# provides one via HELMFILE_KUBE_CONTEXT (see helmfile_kube_context); otherwise
# fall back to the active context.
helmfile_cluster_releases() {
    if [ -n "${HELMFILE_KUBE_CONTEXT:-}" ]; then
        helm list -A --kube-context "$HELMFILE_KUBE_CONTEXT" --output json 2>/dev/null
    else
        helm list -A --output json 2>/dev/null
    fi
}

helmfile_defined_keys() {
    local env="$1"
    helmfile_defined_releases "$env" | jq -r ".[] | $_hf_jq_key" | sort
}

helmfile_selectable_releases() {
    local env="$1" defined cluster
    defined="$(helmfile_defined_releases "$env")" || return 1
    cluster="$(helmfile_cluster_releases)" || return 1
    [ -z "$defined" ] && return 0
    [ -z "$cluster" ] && cluster='[]'
    jq -rn \
        --argjson defined "$defined" \
        --argjson cluster "$cluster" "
        (\$cluster | map(.namespace + \"/\" + .name)) as \$live
        | \$defined[]
        | select(($_hf_jq_key) as \$k | \$live | index(\$k))
        | $_hf_jq_key
    " | sort
}

helmfile_release_meta() {
    local env="$1" key="$2"
    helmfile_defined_releases "$env" | jq -r --arg key "$key" "
        .[] | select($_hf_jq_key == \$key) | [.chart, .version] | @tsv
    " | head -1
}

# Best-effort dependency hint; never fails the caller.
helmfile_dependents() {
    local env="$1"
    export HF_DEP_KEY="$2"
    helmfile -f "$HELMFILE_MAIN" -e "$env" build 2>/dev/null \
        | yq -r '
            .releases[]
            | select((.needs // []) | any_c(. == strenv(HF_DEP_KEY)))
            | (.namespace // "default") + "/" + .name' 2>/dev/null \
        | sort -u || true
    unset HF_DEP_KEY
}
