#!/usr/bin/env bash
# Reusable environment selector.
# Source this file to set the ENV variable.
#
# Usage: source "$SCRIPT_DIR/../lib/env.sh" [environment]
# Sets:  ENV  ("dev" | "prod" | "test")
#
# Resolution order (first match wins):
#   1. the argument, if one is provided
#   2. the ENV variable, if it is already set in the environment
#   3. an interactive gum choose prompt
# `dev`/`prod` are the two operational environments and the only ones the
# interactive picker offers. `test` is a hermetic, tooling-only environment (the
# disposable ephemeral cluster used by @online BDD, issue #35): it is accepted
# only when named explicitly, never presented for interactive selection, so
# operators can never pick it by accident.

_sel_arg="${1:-}"

if [ -n "$_sel_arg" ]; then
    ENV="$_sel_arg"
elif [ -z "${ENV:-}" ]; then
    # Read the selector from the controlling terminal when there is one. Under
    # `mise run` the task's stdin is not the terminal, so gum cannot consume the
    # terminal's probe replies (OSC 11 background colour, cursor position) and
    # they leak onto the screen as stray escape sequences. /dev/tty fixes that;
    # fall back to inherited stdin where no controlling terminal exists.
    _sel_tty=/dev/stdin
    { :</dev/tty; } 2>/dev/null && _sel_tty=/dev/tty
    ENV=$(gum choose \
        --header "Select target environment:" \
        --cursor "> " \
        --cursor.foreground "$GUM_PRIMARY" \
        --selected.foreground "$GUM_PRIMARY" \
        --header.foreground "$GUM_SECONDARY" \
        "dev" "prod" <"$_sel_tty") || { warn "Aborted."; exit 0; }
    unset _sel_tty
fi

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ] && [ "$ENV" != "test" ]; then
    error "Invalid environment '$ENV'. Available: dev, prod (test: tooling-only, explicit)"
    exit 1
fi

unset _sel_arg

# Map an environment to its kubectl context, following the homelab-<env>
# convention used across the repo. Defaults to the resolved $ENV, so callers
# that already sourced this file can simply do: ctx=$(kube_context)
#   kube_context        -> homelab-$ENV
#   kube_context dev    -> homelab-dev
kube_context() {
    local env="${1:-${ENV:-}}"
    printf 'homelab-%s' "$env"
}
