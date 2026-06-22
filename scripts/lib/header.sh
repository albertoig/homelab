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
# kubeContext convention; pass an explicit one as the second argument.
show_subheader() {
    [[ -n "${HOMELAB_SUBHEADER_SHOWN:-}" ]] && return
    export HOMELAB_SUBHEADER_SHOWN=1
    local env="${1:-${ENV:-}}"
    local ctx="${2:-homelab-${env}}"
    gum_secondary "  environment → $(gum_primary --bold "${env}")"
    gum_secondary "  cluster     → $(gum_primary --bold "${ctx}")"
    echo ""
}
