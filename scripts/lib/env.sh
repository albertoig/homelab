#!/usr/bin/env bash
# Reusable environment selector.
# Source this file to set the ENV variable.
#
# Usage: source "$SCRIPT_DIR/../lib/env.sh" [environment]
# Sets:  ENV  ("dev" | "prod")
#
# If an argument is provided it is validated and used directly.
# If no argument is provided a gum choose prompt is shown.

_sel_arg="${1:-}"

if [ -n "$_sel_arg" ]; then
    ENV="$_sel_arg"
else
    ENV=$(gum choose \
        --header "Select target environment:" \
        --cursor "> " \
        --cursor.foreground 212 \
        --selected.foreground 212 \
        --header.foreground 99 \
        "dev" "prod") || { warn "Aborted."; exit 0; }
fi

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    gum log --level error "Invalid environment '$ENV'. Available: dev, prod"
    exit 1
fi

unset _sel_arg
