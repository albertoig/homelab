#!/usr/bin/env bash

show_header() {
    [[ ! -t 1 ]] && return
    [[ -n "${NO_COLOR:-}" ]] && return
    [[ -n "${HOMELAB_HEADER_SHOWN:-}" ]] && return
    export HOMELAB_HEADER_SHOWN=1

    gum style --foreground "$GUM_HEADER" --bold \
" ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
 ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
 ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
 ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
 ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
 ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝"
    gum style --foreground "$GUM_HEADER_SUB" "  Your Cluster, your rules                by Alberto Iglesias"
    echo ""
}

# Sub-header shown under the banner: the selected environment and kube context,
# one per line with a consistent colour scheme. Call after show_header, with ENV
# set (source lib/env.sh first). The context defaults to the homelab-<env>
# kubeContext convention; pass an explicit one as the second argument. Any extra
# "label=value" arguments are appended as additional aligned lines, e.g.
#   show_subheader "$ENV" "$KUBE_CONTEXT" "openbao=https://openbao.internal..."
show_subheader() {
    [[ -n "${HOMELAB_SUBHEADER_SHOWN:-}" ]] && return
    export HOMELAB_SUBHEADER_SHOWN=1
    local env="${1:-${ENV:-}}"
    # Default to the homelab-<env> context via the shared helper (lib/env.sh),
    # which every caller sources before show_subheader.
    local ctx="${2:-$(kube_context "$env")}"
    if [ "$#" -gt 2 ]; then shift 2; else set --; fi
    gum_secondary "  environment → $(gum_primary --bold "${env}")"
    gum_secondary "  cluster     → $(gum_primary --bold "${ctx}")"
    local pair label value
    for pair in "$@"; do
        label="${pair%%=*}"
        value="${pair#*=}"
        printf -v label '%-12s' "$label"
        gum_secondary "  ${label}→ $(gum_primary --bold "${value}")"
    done
    echo ""
}
