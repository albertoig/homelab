#!/bin/bash
# Initialize secrets for an environment from per-chart template files.
# Iterates over each secret template, prompts for values, generates .secrets.yaml
# files, and encrypts them with sops.
#
# Usage: ./scripts/init-secrets.sh <environment>
# Example: ./scripts/init-secrets.sh prod

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colors.sh"

HELMFILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$HELMFILE_DIR/helmfile/secret-templates"
ENVIRONMENT="${1:-}"

# --- Validation ---

if [ -z "$ENVIRONMENT" ]; then
    error "Usage: $0 <environment>"
    info "Available environments: dev, prod"
    exit 1
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    error "Invalid environment '$ENVIRONMENT'."
    info "Available environments: dev, prod"
    exit 1
fi

SECRETS_DIR="$HELMFILE_DIR/helmfile/environments/$ENVIRONMENT/secrets"

if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls "$TEMPLATES_DIR"/*.template.yaml 2>/dev/null)" ]; then
    error "No template files found in $TEMPLATES_DIR"
    exit 1
fi

mkdir -p "$SECRETS_DIR"

# --- Helpers ---

# Escape a value for YAML output: wrap in quotes if it contains special chars
yaml_value() {
    local val="$1"
    # Always quote if value matches any YAML special character or whitespace
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
    local dq=$'\x22'  # double quote
    local sq=$'\x27'  # single quote
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

# Look up a value in a YAML file by dot-separated path (e.g., "authentik.email.from")
# Uses Python for reliable YAML parsing
yaml_lookup() {
    local file="$1"
    local path="$2"
    python3 -c "
import yaml, sys
try:
    with open('$file') as f:
        data = yaml.safe_load(f)
    keys = '$path'.split('.')
    for k in keys:
        if isinstance(data, dict) and k in data:
            data = data[k]
        elif isinstance(data, list) and data:
            print(data[0])
            sys.exit(0)
        else:
            sys.exit(0)
    if data is not None:
        print(data)
except Exception:
    sys.exit(0)
" 2>/dev/null || true
}

# --- Main ---

header "Initializing secrets for environment: $ENVIRONMENT"
echo ""

TOTAL_ENCRYPTED=0
TOTAL_FAILED=0

for template in "$TEMPLATES_DIR"/*.template.yaml; do
    chart_name=$(basename "$template" .template.yaml)
    secrets_file="$SECRETS_DIR/${chart_name}.secrets.yaml"
    enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

    # --- Check existing secrets ---
    existing_source=""
    if [ -f "$enc_file" ]; then
        existing_source=$(mktemp "${TMPDIR:-/tmp}/${chart_name}.existing.XXXXXX")
        if ! sops --decrypt "$enc_file" > "$existing_source" 2>/dev/null; then
            existing_source=""
            rm -f "$existing_source" 2>/dev/null
        fi
    elif [ -f "$secrets_file" ]; then
        existing_source="$secrets_file"
    fi

    # --- Ask to overwrite or proceed ---
    if [ -n "$existing_source" ]; then
        echo -e "${_C_CYAN}  [$chart_name]${_C_RESET} Secrets already exist."
        read -rp "$(echo -e "  ${_C_YELLOW}Overwrite? [y/N] ${_C_RESET}")" confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "[$chart_name] Skipping."
            echo ""
            # Clean up temp file
            [[ "$existing_source" == "${TMPDIR:-/tmp}/"* ]] && rm -f "$existing_source"
            continue
        fi
        echo ""
    fi

    # --- Phase 1: Parse template into entries ---
    entries=0
    declare -a entry_path=()
    declare -a entry_desc=()
    declare -a entry_type=()
    declare -a entry_indent=()
    declare -a path_parts=()

    current_desc=""
    indent_level=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip blank lines
        [[ "$line" =~ ^[[:space:]]*$ ]] && { current_desc=""; continue; }

        # Skip section header comments (# --- name ---)
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*--- ]]; then
            current_desc=""
            continue
        fi

        # Accumulate comment lines
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            comment="${line#"${line%%[![:space:]]*}"}"
            comment="${comment#\#}"
            comment="${comment#"${comment%%[![:space:]]*}"}"
            if [ -n "$current_desc" ]; then
                current_desc="$current_desc $comment"
            else
                current_desc="$comment"
            fi
            continue
        fi

        # Calculate indentation (2 spaces per level)
        leading="${line%%[![:space:]]*}"
        indent_level=$(( ${#leading} / 2 ))

        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

        if [[ "$trimmed" == "- \"\"" ]]; then
            # List item placeholder
            path_parts[$indent_level]="_item"
            p=$(build_path "$indent_level")
            entry_path[$entries]="$p"
            entry_desc[$entries]="$current_desc"
            entry_type[$entries]="list_item"
            entry_indent[$entries]=$indent_level
            entries=$((entries + 1))
            current_desc=""
        else
            # Key: value line
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
                    entries=$((entries + 1))
                fi
                current_desc=""
            fi
        fi
    done < "$template"

    # --- Phase 2: Prompt for values ---

    echo -e "${_C_BOLD}${_C_CYAN}  === $chart_name ===${_C_RESET}"

    if [ "$entries" -eq 0 ]; then
        warn "[$chart_name] No secret values found in template."
        echo ""
        continue
    fi

    declare -a responses_key=()
    declare -a responses_val=()
    rcount=0

    for ((i = 0; i < entries; i++)); do
        desc="${entry_desc[$i]}"
        kp="${entry_path[$i]}"

        # Look up existing value using Python YAML parser
        existing=""
        if [ -n "$existing_source" ]; then
            existing=$(yaml_lookup "$existing_source" "$kp")
        fi

        # Display description and example
        if [ -n "$desc" ]; then
            echo ""
            echo -e "    ${_C_BLUE}${desc}${_C_RESET}"
        fi

        # Prompt
        if [ -n "$existing" ]; then
            printf "    ${_C_YELLOW}%s${_C_RESET} [%s]: " "$kp" "$existing"
        else
            printf "    ${_C_YELLOW}%s${_C_RESET}: " "$kp"
        fi

        read -r response

        # Use existing value if no new input
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
            # Blank lines
            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                echo ""
                current_desc=""
                continue
            fi

            # Pass through section header comments
            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*--- ]]; then
                echo "$line"
                current_desc=""
                continue
            fi

            # Pass through comments (strip trailing spaces only)
            if [[ "$line" =~ ^[[:space:]]*# ]]; then
                echo "$line"
                continue
            fi

            # YAML content line
            leading="${line%%[![:space:]]*}"
            indent_level=$(( ${#leading} / 2 ))
            trimmed="${line#"${line%%[![:space:]]*}"}"
            trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

            if [[ "$trimmed" == "- \"\"" ]]; then
                # List item — look up response by path
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
                # Key: value line
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

    success "[$chart_name] Created $(basename "$secrets_file")"

    # Clean up temporary decrypted file
    if [[ "$existing_source" == /tmp/* ]] || [[ "$existing_source" == "${TMPDIR:-/tmp}/"* ]]; then
        rm -f "$existing_source"
    fi

    unset entry_path entry_desc entry_type entry_indent path_parts responses_key responses_val
done

# --- Encrypt all .secrets.yaml files ---

echo ""
header "Encrypting secrets for $ENVIRONMENT"

for secrets_file in "$SECRETS_DIR"/*.secrets.yaml; do
    [ -f "$secrets_file" ] || continue
    chart_name=$(basename "$secrets_file" .secrets.yaml)
    enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

    info "Encrypting: $(basename "$secrets_file") -> $(basename "$enc_file")"
    if sops --encrypt "$secrets_file" > "$enc_file" 2>/dev/null; then
        success "Created $(basename "$enc_file")"
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
    success "All $TOTAL_ENCRYPTED secret file(s) encrypted for $ENVIRONMENT."
fi
