#!/usr/bin/env bash
# Reusable environment selector.
# Source this file to set the ENV variable.
#
# Usage: source "$SCRIPT_DIR/../lib/env.sh" [environment]
# Sets:  ENV  ("dev" | "prod")
#
# Resolution order (first match wins):
#   1. the argument, if one is provided
#   2. the ENV variable, if it is already set in the environment
#   3. an interactive gum choose prompt
# The result is validated against dev/prod either way.

_sel_arg="${1:-}"

if [ -n "$_sel_arg" ]; then
    ENV="$_sel_arg"
elif [ -z "${ENV:-}" ]; then
    ENV=$(gum choose \
        --header "Select target environment:" \
        --cursor "> " \
        --cursor.foreground "$GUM_PRIMARY" \
        --selected.foreground "$GUM_PRIMARY" \
        --header.foreground "$GUM_SECONDARY" \
        "dev" "prod") || { warn "Aborted."; exit 0; }
fi

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    gum log --level error "Invalid environment '$ENV'. Available: dev, prod"
    exit 1
fi

unset _sel_arg
