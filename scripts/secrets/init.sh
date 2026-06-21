#!/usr/bin/env bash
# Initialize secrets for an environment from per-chart template files.
# Iterates over each secret template, prompts for values, generates encrypted
# secrets files with sops.
#
# Usage: ./scripts/secrets/init.sh [environment]
# Example: ./scripts/secrets/init.sh prod

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"

HELMFILE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES_DIR="$HELMFILE_DIR/helmfile/secret-templates"

# --- Gum check ---

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

# --- Environment ---

source "$SCRIPT_DIR/../lib/env.sh" "${1:-}"

SECRETS_DIR="$HELMFILE_DIR/helmfile/environments/$ENV/secrets"

if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls "$TEMPLATES_DIR"/*.template.yaml 2>/dev/null)" ]; then
    error "No template files found in $TEMPLATES_DIR"
    exit 1
fi

mkdir -p "$SECRETS_DIR"

# --- Header ---

clear
show_header
gum_secondary "  environment → $(gum_primary --bold "$ENV")"
echo ""

# --- Helpers ---

source "$SCRIPT_DIR/../lib/secrets.sh"

# --- Main ---

TOTAL_ENCRYPTED=0
TOTAL_FAILED=0

for template in "$TEMPLATES_DIR"/*.template.yaml; do
    chart_name=$(basename "$template" .template.yaml)
    secrets_file="$SECRETS_DIR/${chart_name}.secrets.yaml"
    enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

    # Section header
    gum style \
        --border normal \
        --border-foreground "$GUM_SECONDARY" \
        --padding "0 1" \
        "$(gum_primary --bold "$chart_name")"
    echo ""

    # --- Check existing secrets ---
    existing_source=""
    has_existing=false
    if [ -f "$enc_file" ]; then
        has_existing=true
        _tmp=$(mktemp "${TMPDIR:-/tmp}/${chart_name}.existing.XXXXXX")
        if sops --decrypt "$enc_file" > "$_tmp" 2>/dev/null; then
            existing_source="$_tmp"
        else
            rm -f "$_tmp"
        fi
    elif [ -f "$secrets_file" ]; then
        has_existing=true
        existing_source="$secrets_file"
    fi

    # --- Ask before proceeding — always, for every chart ---
    if $has_existing; then
        if ! gum confirm --default=false "Secrets already exist for '$chart_name'. Overwrite?"; then
            info "Skipped $chart_name."
            echo ""
            [[ "$existing_source" == "${TMPDIR:-/tmp}/"* ]] && rm -f "$existing_source" || true
            continue
        fi
    else
        if ! gum confirm "Configure secrets for '$chart_name'?"; then
            info "Skipped $chart_name."
            echo ""
            continue
        fi
    fi
    echo ""

    # --- Phase 1: Parse template into entries ---
    entries=0
    declare -a entry_path=()
    declare -a entry_desc=()
    declare -a entry_type=()
    declare -a entry_indent=()
    declare -a entry_autogen=()
    declare -a entry_visible=()
    declare -a path_parts=()

    current_desc=""
    current_autogen=""
    current_visible=false
    indent_level=0

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:space:]]*$ ]]; then
            current_desc=""
            current_autogen=""
            current_visible=false
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*--- ]]; then
            current_desc=""
            current_autogen=""
            current_visible=false
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            comment="${line#"${line%%[![:space:]]*}"}"
            comment="${comment#\#}"
            comment="${comment#"${comment%%[![:space:]]*}"}"
            if [[ "$comment" == @autogen:* ]]; then
                current_autogen="${comment#@autogen:}"
                current_autogen="${current_autogen#"${current_autogen%%[![:space:]]*}"}"
            elif [[ "$comment" == "@visible" ]]; then
                # Prompt for this field with visible (non-masked) input.
                current_visible=true
            else
                if [ -n "$current_desc" ]; then
                    current_desc="$current_desc $comment"
                else
                    current_desc="$comment"
                fi
            fi
            continue
        fi

        leading="${line%%[![:space:]]*}"
        indent_level=$(( ${#leading} / 2 ))
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

        if [[ "$trimmed" == "- \"\"" ]]; then
            path_parts[$indent_level]="_item"
            p=$(build_path "$indent_level")
            entry_path[$entries]="$p"
            entry_desc[$entries]="$current_desc"
            entry_type[$entries]="list_item"
            entry_indent[$entries]=$indent_level
            entry_autogen[$entries]="$current_autogen"
            entry_visible[$entries]="$current_visible"
            entries=$((entries + 1))
            current_desc=""
            current_autogen=""
            current_visible=false
        else
            colon_pos=$(find_colon "$trimmed")
            if [ "$colon_pos" -gt 0 ]; then
                key="${trimmed:0:$((colon_pos - 1))}"
                key="${key%"${key##*[![:space:]]}"}"
                value="${trimmed:$colon_pos}"
                value="${value#"${value%%[![:space:]]*}"}"

                path_parts[$indent_level]="$key"

                if [ "$value" = '""' ]; then
                    p=$(build_path "$((indent_level + 1))")
                    entry_path[$entries]="$p"
                    entry_desc[$entries]="$current_desc"
                    entry_type[$entries]="value"
                    entry_indent[$entries]=$indent_level
                    entry_autogen[$entries]="$current_autogen"
                    entry_visible[$entries]="$current_visible"
                    entries=$((entries + 1))
                fi
                current_desc=""
                current_autogen=""
                current_visible=false
            fi
        fi
    done < "$template"

    # --- Phase 2: Prompt for values ---

    if [ "$entries" -eq 0 ]; then
        warn "No secret fields found in template for $chart_name."
        echo ""
        continue
    fi

    declare -a responses_key=()
    declare -a responses_val=()
    rcount=0

    for ((i = 0; i < entries; i++)); do
        desc="${entry_desc[$i]}"
        kp="${entry_path[$i]}"
        autogen="${entry_autogen[$i]:-}"
        visible="${entry_visible[$i]:-false}"

        existing=""
        if [ -n "$existing_source" ]; then
            existing=$(yaml_lookup "$existing_source" "$kp")
        fi

        if [ -n "$desc" ]; then
            gum_hint "  $desc"
        fi

        response=""

        if [ -n "$autogen" ]; then
            if gum confirm --default=true "  Auto-generate $(gum_accent "$kp")?"; then
                response=$(eval "$autogen")
                info "Auto-generated $kp"
            else
                placeholder=""
                [ -n "$existing" ] && placeholder="(press enter to keep existing)"
                response=$(gum input \
                    --password \
                    --prompt "  $(gum_accent "$kp"): " \
                    --placeholder "$placeholder" \
                    --width 60) || { warn "Aborted."; exit 0; }
            fi
        else
            placeholder=""
            [ -n "$existing" ] && placeholder="(press enter to keep existing)"
            if [ "$visible" = true ]; then
                # Non-masked: the value is not display-sensitive (e.g. username,
                # name, email). It is still written to the sops-encrypted secret.
                response=$(gum input \
                    --prompt "  $(gum_accent "$kp"): " \
                    --placeholder "$placeholder" \
                    --width 60) || { warn "Aborted."; exit 0; }
            else
                response=$(gum input \
                    --password \
                    --prompt "  $(gum_accent "$kp"): " \
                    --placeholder "$placeholder" \
                    --width 60) || { warn "Aborted."; exit 0; }
            fi
        fi

        if [ -z "$response" ] && [ -n "$existing" ]; then
            response="$existing"
        fi

        if [ -n "$response" ]; then
            responses_key[$rcount]="$kp"
            responses_val[$rcount]="$response"
            rcount=$((rcount + 1))
        fi
    done

    echo ""

    # --- Phase 3: Generate .secrets.yaml ---

    {
        current_desc=""
        indent_level=0

        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                echo ""
                current_desc=""
                continue
            fi

            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*--- ]]; then
                echo "$line"
                current_desc=""
                continue
            fi

            if [[ "$line" =~ ^[[:space:]]*# ]]; then
                echo "$line"
                continue
            fi

            leading="${line%%[![:space:]]*}"
            indent_level=$(( ${#leading} / 2 ))
            trimmed="${line#"${line%%[![:space:]]*}"}"
            trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

            if [[ "$trimmed" == "- \"\"" ]]; then
                p=$(build_path "$indent_level")
                found=false
                for ((r = 0; r < rcount; r++)); do
                    if [ "${responses_key[$r]}" = "$p" ]; then
                        echo "${leading}- $(yaml_value "${responses_val[$r]}")"
                        found=true
                        break
                    fi
                done
                if ! $found; then echo "$line"; fi
            else
                colon_pos=$(find_colon "$trimmed")
                if [ "$colon_pos" -gt 0 ]; then
                    key="${trimmed:0:$((colon_pos - 1))}"
                    key="${key%"${key##*[![:space:]]}"}"
                    value="${trimmed:$colon_pos}"
                    value="${value#"${value%%[![:space:]]*}"}"

                    path_parts[$indent_level]="$key"

                    if [ "$value" = '""' ]; then
                        p=$(build_path "$((indent_level + 1))")
                        found=false
                        for ((r = 0; r < rcount; r++)); do
                            if [ "${responses_key[$r]}" = "$p" ]; then
                                echo "${leading}${key}: $(yaml_value "${responses_val[$r]}")"
                                found=true
                                break
                            fi
                        done
                        if ! $found; then echo "$line"; fi
                    else
                        echo "$line"
                    fi
                else
                    echo "$line"
                fi
            fi
        done < "$template"
    } > "$secrets_file"

    info "Generated $(basename "$secrets_file")"

    # Clean up temporary decrypted file
    [[ "$existing_source" == "${TMPDIR:-/tmp}/"* ]] && rm -f "$existing_source" || true

    unset entry_path entry_desc entry_type entry_indent entry_autogen entry_visible path_parts responses_key responses_val
done

# --- Encrypt ---

echo ""
gum_secondary --bold "  Encrypting secrets for $ENV..."
echo ""

for secrets_file in "$SECRETS_DIR"/*.secrets.yaml; do
    [ -f "$secrets_file" ] || continue
    chart_name=$(basename "$secrets_file" .secrets.yaml)
    enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

    if SOPS_IN="$secrets_file" SOPS_OUT="$enc_file" gum spin \
        --spinner pulse \
        --show-error \
        --title "  $(basename "$secrets_file") → $(basename "$enc_file")" \
        -- bash -c 'sops --encrypt "$SOPS_IN" > "$SOPS_OUT"'; then
        rm -f "$secrets_file"
        info "Created $(basename "$enc_file")"
        TOTAL_ENCRYPTED=$((TOTAL_ENCRYPTED + 1))
    else
        error "Failed to encrypt $(basename "$secrets_file")"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
done

echo ""
if [ "$TOTAL_FAILED" -gt 0 ]; then
    warn "Encrypted $TOTAL_ENCRYPTED file(s), $TOTAL_FAILED failed."
else
    gum style \
        --border rounded \
        --border-foreground "$GUM_PRIMARY" \
        --align center \
        --padding "1 4" \
        --margin "1 2" \
        "$(gum_primary --bold "✓  $TOTAL_ENCRYPTED secret(s) encrypted for $ENV.")"
fi
