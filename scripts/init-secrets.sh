#!/bin/bash
# Initialize secrets for an environment from per-chart template files.
# Prompts interactively for each secret value, generates per-chart .secrets.yaml
# files, and encrypts them with sops.
#
# Usage: ./scripts/init-secrets.sh <environment>
# Example: ./scripts/init-secrets.sh prod

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colors.sh"

HELMFILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$HELMFILE_DIR/helmfile/secret-templates"
ENVIRONMENT="${1:-}"

# Colors for interactive prompts (local to this script)
_C_CYAN='\033[0;36m'
_C_YELLOW='\033[0;33m'
_C_RESET='\033[0m'

# Suppress colors if not a terminal
if [[ ! -t 1 ]]; then
    _C_CYAN=''
    _C_YELLOW=''
    _C_RESET=''
fi

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

# Check for template files
if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls "$TEMPLATES_DIR"/*.template.yaml 2>/dev/null)" ]; then
    error "No template files found in $TEMPLATES_DIR"
    exit 1
fi

# Ensure secrets directory exists
mkdir -p "$SECRETS_DIR"

# --- AWK helpers (used across phases) ---

AWK_TRIM='function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }'
AWK_FIND_COLON='function find_colon(line,    i, c, in_quote) {
    in_quote = 0
    for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "\042" || c == "\047") in_quote = !in_quote
        if (!in_quote && c == ":") return i
    }
    return 0
}'
AWK_BUILD_PATH='function build_path(ilen,    p, k) {
    p = ""; for (k = 0; k < ilen; k++) p = p (k == 0 ? "" : ".") key_stack[k]; return p
}'

# --- Phase 1: Extract key paths, descriptions, and current values ---

header "Initializing secrets for environment: $ENVIRONMENT"
echo ""

extract_key_paths() {
    local template_file="$1"
    local section="$2"

    awk -v section="$section" '
    '"$AWK_TRIM"'
    '"$AWK_FIND_COLON"'
    '"$AWK_BUILD_PATH"'

    BEGIN { indent = 0; desc = "" }

    /^[ \t]*$/ { desc = ""; next }
    /^[ \t]*# ---/ { desc = ""; next }
    /^[ \t]*#/ { gsub(/^[ \t]*#[ \t]*/, ""); desc = desc (desc == "" ? "" : " ") $0; next }

    {
        leading = 0
        while (substr($0, leading + 1, 1) == " " || substr($0, leading + 1, 1) == "\t") leading++
        new_indent = int(leading / 2)

        is_list = match($0, /^[ \t]*-[ \t]*""[ \t]*$/)
        colon_pos = find_colon($0)
        is_kv = (!is_list && colon_pos > 0)

        if (is_kv) {
            key = trim(substr($0, leading + 1, colon_pos - leading - 1))
            key_stack[new_indent] = key
        }

        indent = new_indent

        if (is_list) {
            print section "\t" build_path(indent) "\t" desc "\tlist_item"
        } else if (is_kv) {
            value = trim(substr($0, colon_pos + 1))
            if (value == "\042\042") {
                print section "\t" build_path(indent + 1) "\t" desc "\tvalue"
            }
        }

        desc = ""
    }
    ' "$template_file"
}

# Extract section name from template file (from # --- name --- comment)
get_section_name() {
    awk '
    /^[ \t]*# ---/ {
        s = $0
        gsub(/^[ \t]*#[ \t]*/, "", s)
        gsub(/^[[:space:]]*---[[:space:]]*/, "", s)
        gsub(/[[:space:]]*---[[:space:]]*$/, "", s)
        gsub(/^[ \t]+|[ \t]+$/, "", s)
        print s
        exit
    }
    ' "$1"
}

# Collect key paths from all templates
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

ALL_ENTRIES="$TMPDIR_WORK/all_entries.txt"
> "$ALL_ENTRIES"

for template in "$TEMPLATES_DIR"/*.template.yaml; do
    section=$(get_section_name "$template")
    if [ -z "$section" ]; then
        section=$(basename "$template" .template.yaml)
    fi
    extract_key_paths "$template" "$section" >> "$ALL_ENTRIES"
done

if [ ! -s "$ALL_ENTRIES" ]; then
    warn "No secret values found in templates."
    exit 0
fi

# --- Phase 2: Check for existing per-chart secrets ---

# Find existing source for pre-filling: prefer .secrets.yaml, fallback to sops-decrypt .enc.yaml
get_existing_source() {
    local chart_name="$1"
    local secrets_file="$SECRETS_DIR/${chart_name}.secrets.yaml"
    local enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

    if [ -f "$secrets_file" ]; then
        echo "$secrets_file"
    elif [ -f "$enc_file" ]; then
        local decrypted="$TMPDIR_WORK/${chart_name}.existing.yaml"
        sops --decrypt "$enc_file" > "$decrypted" 2>/dev/null && echo "$decrypted" || true
    fi
}

# Check if any chart already has secrets (for overwrite warning)
any_existing=false
while IFS=$'\t' read -r section rest; do
    existing_source=$(get_existing_source "$section")
    if [ -n "$existing_source" ]; then
        any_existing=true
        break
    fi
done < "$ALL_ENTRIES"

if [ "$any_existing" = true ]; then
    warn "Some charts already have secrets in: $SECRETS_DIR"
    echo ""
    msg "${_C_YELLOW}  Existing per-chart secrets:${_C_RESET}"
    for f in "$SECRETS_DIR"/*.secrets.yaml "$SECRETS_DIR"/*.enc.yaml; do
        [ -f "$f" ] && msg "    $(basename "$f")"
    done
    echo ""
    read -rp "$(echo -e "${_C_YELLOW}  Overwrite existing values? [y/N] ${_C_RESET}")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Aborted. Existing secrets preserved."
        exit 0
    fi
    echo ""
fi

# --- Phase 3: Prompt for values ---

RESPONSES_FILE="$TMPDIR_WORK/responses.txt"
> "$RESPONSES_FILE"

current_section=""

while IFS=$'\t' read -r section key_path description line_type; do
    [ -z "$key_path" ] && continue

    # Show section header when it changes
    if [ "$section" != "$current_section" ]; then
        [ -n "$current_section" ] && echo ""
        echo -e "${_C_CYAN}  === $section ===${_C_RESET}"
        current_section="$section"
    fi

    # Show description
    if [ -n "$description" ]; then
        echo -e "  ${description}"
    fi

    # Get existing value from per-chart source
    existing=""
    existing_source=$(get_existing_source "$section")
    if [ -n "$existing_source" ]; then
        existing=$(awk -v kp="$key_path" '
        '"$AWK_TRIM"'
        '"$AWK_FIND_COLON"'
        '"$AWK_BUILD_PATH"'

        BEGIN { indent = 0 }
        /^[ \t]*$/ { next }
        /^[ \t]*#/ { next }

        {
            leading = 0
            while (substr($0, leading + 1, 1) == " " || substr($0, leading + 1, 1) == "\t") leading++
            new_indent = int(leading / 2)

            is_list = match($0, /^[ \t]*-[ \t]*""[ \t]*$/)
            colon_pos = find_colon($0)
            is_kv = (!is_list && colon_pos > 0)

            if (is_kv) {
                key = trim(substr($0, leading + 1, colon_pos - leading - 1))
                key_stack[new_indent] = key
            }
            indent = new_indent

            if (is_list) {
                path = build_path(indent)
                if (path == kp) {
                    val = trim(substr($0, leading + 2))
                    gsub(/^-[ \t]*/, "", val)
                    gsub(/^\042|\042$/, "", val)
                    print val
                    exit
                }
            } else if (is_kv) {
                path = build_path(indent + 1)
                if (path == kp) {
                    val = trim(substr($0, colon_pos + 1))
                    gsub(/^\042|\042$/, "", val)
                    print val
                    exit
                }
            }
        }
        ' "$existing_source")
    fi

    # Display prompt
    if [ -n "$existing" ]; then
        printf "    ${_C_YELLOW}%s${_C_RESET} [%s]: " "$key_path" "$existing"
    else
        printf "    ${_C_YELLOW}%s${_C_RESET}: " "$key_path"
    fi

    read -r response

    # Use existing value if no response given
    if [ -z "$response" ] && [ -n "$existing" ]; then
        response="$existing"
    fi

    # Skip if still empty (user chose to leave blank)
    if [ -z "$response" ]; then
        continue
    fi

    echo "${key_path}|${response}" >> "$RESPONSES_FILE"

done < "$ALL_ENTRIES"

echo ""

# --- Phase 4: Generate per-chart .secrets.yaml files ---

info "Generating per-chart secrets files..."

generate_output() {
    local template_file="$1"

    awk -v responses_file="$RESPONSES_FILE" '
    '"$AWK_TRIM"'
    '"$AWK_FIND_COLON"'
    '"$AWK_BUILD_PATH"'

    BEGIN {
        while ((getline line < responses_file) > 0) {
            idx = index(line, "|")
            if (idx > 0) {
                responses[substr(line, 1, idx - 1)] = substr(line, idx + 1)
            }
        }
        close(responses_file)
        indent = 0
    }

    # Skip comments and blank lines
    /^[ \t]*#/ { next }
    /^[ \t]*$/ { next }

    {
        leading = 0
        while (substr($0, leading + 1, 1) == " " || substr($0, leading + 1, 1) == "\t") leading++
        new_indent = int(leading / 2)

        is_list = match($0, /^[ \t]*-[ \t]*""[ \t]*$/)
        colon_pos = find_colon($0)
        is_kv = (!is_list && colon_pos > 0)

        if (is_kv) {
            key = trim(substr($0, leading + 1, colon_pos - leading - 1))
            key_stack[new_indent] = key
        }
        indent = new_indent

        if (is_list) {
            path = build_path(indent)
            if (path in responses) {
                print substr($0, 1, leading) "- " responses[path]
            } else {
                print $0
            }
        } else if (is_kv) {
            path = build_path(indent + 1)
            value = trim(substr($0, colon_pos + 1))
            if (value == "\042\042" && (path in responses)) {
                print substr($0, 1, leading) key ": " responses[path]
            } else {
                print $0
            }
        } else {
            print $0
        }
    }
    ' "$template_file"
}

for template in "$TEMPLATES_DIR"/*.template.yaml; do
    chart_name=$(get_section_name "$template")
    if [ -z "$chart_name" ]; then
        chart_name=$(basename "$template" .template.yaml)
    fi
    output_file="$SECRETS_DIR/${chart_name}.secrets.yaml"
    generate_output "$template" > "$output_file"
    success "Created: $output_file"
done

# --- Phase 5: Encrypt per-chart files ---

echo ""
header "Encrypting per-chart secrets"

encrypted=0
failed=0

for secrets_file in "$SECRETS_DIR"/*.secrets.yaml; do
    [ -f "$secrets_file" ] || continue
    chart_name=$(basename "$secrets_file" .secrets.yaml)
    enc_file="$SECRETS_DIR/${chart_name}.enc.yaml"

    info "Encrypting: ${chart_name}.secrets.yaml -> ${chart_name}.enc.yaml"
    if sops --encrypt "$secrets_file" > "$enc_file" 2>/dev/null; then
        success "Created: $(basename "$enc_file")"
        encrypted=$((encrypted + 1))
    else
        error "Failed to encrypt: $(basename "$secrets_file")"
        failed=$((failed + 1))
    fi
done

echo ""
if [ "$failed" -gt 0 ]; then
    warn "Encrypted $encrypted chart(s), $failed failed."
else
    success "All $encrypted chart(s) encrypted successfully!"
fi
