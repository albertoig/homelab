#!/usr/bin/env bash
# Shared helmfile helpers for single-release tooling.
# Source after lib/colors.sh. Requires: helmfile, helm, jq, yq.
#
# Public API (consumed by scripts/helm/destroy-one.sh and scripts/helm/install-one.sh):
#   helmfile_defined_releases <env>     -> JSON array of releases the Helmfile defines
#   helmfile_cluster_releases           -> JSON array of releases helm reports installed
#   helmfile_cluster_keys               -> "namespace/name" per installed cluster release
#   helmfile_defined_keys <env>         -> "namespace/name" per defined release (one/line)
#   helmfile_selectable_releases <env>  -> "namespace/name" per defined AND deployed release (delete set)
#   helmfile_installable_rows <env>     -> "namespace/name\t<install|update>" per defined release (install set)
#   helmfile_release_meta <env> <key>   -> "<chart>\t<version>" for a defined release
#   helmfile_dependents <env> <key>     -> "namespace/name" per release whose needs: hits <key>
#   helmfile_requirements <env> <key>   -> "namespace/name" per release that <key> lists in needs:
#
# The guiding rule for every selector here is: THE YAML IS THE SOURCE OF TRUTH.
# A release the Helmfile does not define is NEVER actionable, even when it is
# running in the cluster — such releases stay invisible to these helpers, so
# callers can never act on unmanaged releases.
#
# There are two "selectable" notions sharing that one guard:
#   • DELETE (destroy-one): defined AND currently deployed — you can only uninstall
#     what is actually running          → helmfile_selectable_releases.
#   • INSTALL/UPDATE (install-one): defined, deployed or not — not-deployed becomes
#     an "install", already-deployed an "update" → helmfile_installable_rows.

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

helmfile_cluster_keys() {
    helmfile_cluster_releases | jq -r '.[]? | .namespace + "/" + .name' 2>/dev/null | sort
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

# Install/update targets: EVERY defined release (deployed or not), tagged with the
# action a sync would perform — "update" when the release is already in the cluster,
# else "install". Releases running in the cluster but NOT defined here never appear,
# so the unmanaged guard holds exactly as it does for the delete set.
helmfile_installable_rows() {
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
        | ($_hf_jq_key) as \$k
        | [ \$k, (if (\$live | index(\$k)) then \"update\" else \"install\" end) ] | @tsv
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

# Best-effort prerequisite hint — the release's OWN needs:; never fails the caller.
helmfile_requirements() {
    local env="$1"
    export HF_REL_KEY="$2"
    helmfile -f "$HELMFILE_MAIN" -e "$env" build 2>/dev/null \
        | yq -r '
            .releases[]
            | select(((.namespace // "default") + "/" + .name) == strenv(HF_REL_KEY))
            | (.needs // [])[]' 2>/dev/null \
        | sort -u || true
    unset HF_REL_KEY
}
