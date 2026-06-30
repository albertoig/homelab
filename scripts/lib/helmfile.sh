#!/usr/bin/env bash
# Shared helmfile helpers for single-release tooling.
# Source after lib/colors.sh. Requires: helmfile, helm, jq, yq.
#
# Public API (consumed by scripts/helm/destroy-one.sh, and reusable by the
# sibling install-one feature, #29):
#   helmfile_defined_releases <env>     -> JSON array of releases the Helmfile defines
#   helmfile_cluster_releases           -> JSON array of releases helm reports installed
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

helmfile_cluster_releases() {
    helm list -A --output json 2>/dev/null
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
