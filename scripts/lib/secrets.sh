#!/usr/bin/env bash
# YAML helper functions for secrets scripts.
# Source this file; do not execute directly.

# Escape a value for YAML output: wrap in quotes if it contains special chars
yaml_value() {
    local val="$1"
    local special=':*#{}&!|>%@`[]-?'
    local needs_quote=false
    if [[ "$val" =~ [[:space:]] ]]; then
        needs_quote=true
    elif [[ "${val:0:1}" =~ [?\[-] ]]; then
        needs_quote=true
    else
        for ((ci = 0; ci < ${#val}; ci++)); do
            if [[ "$special" == *"${val:$ci:1}"* ]]; then
                needs_quote=true
                break
            fi
        done
    fi
    if $needs_quote; then
        val="${val//\\/\\\\}"
        val="${val//\"/\\\"}"
        echo "\"$val\""
    else
        echo "$val"
    fi
}

# Build dot-separated path from path_parts array up to given depth
build_path() {
    local depth=$1
    local p=""
    for ((i = 0; i < depth; i++)); do
        [ -n "$p" ] && p="${p}."
        p="${p}${path_parts[$i]}"
    done
    echo "$p"
}

# Find the position (1-indexed) of the first unquoted colon in a string
find_colon() {
    local s="$1"
    local in_quote=0
    local dq=$'\x22'
    local sq=$'\x27'
    for ((j = 0; j < ${#s}; j++)); do
        local c="${s:$j:1}"
        if [[ "$c" == "$dq" ]] || [[ "$c" == "$sq" ]]; then
            in_quote=$((1 - in_quote))
        elif [[ "$c" == ":" ]] && [ "$in_quote" -eq 0 ]; then
            echo $((j + 1))
            return
        fi
    done
    echo 0
}

# Look up a value in a YAML file by dot-separated path (e.g., "authentik.email.from").
# Lists resolve to their first element; missing paths return empty.
yaml_lookup() {
    local file="$1"
    local path="$2"
    yq eval ".${path} | ((select(tag == \"!!seq\") | .[0]) // .) // \"\"" "$file" 2>/dev/null || true
}
