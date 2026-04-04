#!/bin/bash
# Check that all secret files are present and have the same fields as their templates.
# Usage: ./scripts/check-secrets.sh [environment]
# If no environment is given, checks all environments.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/colors.sh"

HELMFILE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$HELMFILE_DIR/helmfile/secret-templates"
ENVS_DIR="$HELMFILE_DIR/helmfile/environments"

TARGET_ENV="${1:-}"

ERRORS=0
WARNINGS=0

# --- Determine environments to check ---

if [ -n "$TARGET_ENV" ]; then
    if [ ! -d "$ENVS_DIR/$TARGET_ENV" ]; then
        error "Environment '$TARGET_ENV' not found in $ENVS_DIR"
        exit 1
    fi
    ENVIRONMENTS=("$TARGET_ENV")
else
    ENVIRONMENTS=()
    for d in "$ENVS_DIR"/*/; do
        [ -d "$d" ] && ENVIRONMENTS+=("$(basename "$d")")
    done
fi

# --- Check templates exist ---

if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls "$TEMPLATES_DIR"/*.template.yaml 2>/dev/null)" ]; then
    error "No template files found in $TEMPLATES_DIR"
    exit 1
fi

# --- Python helper for YAML key extraction ---

extract_keys_py() {
    python3 -c "
import yaml, sys

def leaf_paths(data, prefix=''):
    paths = []
    if isinstance(data, dict):
        for k, v in data.items():
            new_prefix = f'{prefix}.{k}' if prefix else k
            if isinstance(v, (dict, list)):
                paths.extend(leaf_paths(v, new_prefix))
            else:
                paths.append(new_prefix)
    elif isinstance(data, list):
        for item in data:
            new_prefix = f'{prefix}[]'
            if isinstance(item, (dict, list)):
                paths.extend(leaf_paths(item, new_prefix))
            else:
                paths.append(new_prefix)
    return paths

try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
    if data is None:
        sys.exit(1)
    keys = sorted(set(leaf_paths(data)))
    for k in keys:
        print(k)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" "$1" 2>/dev/null
}

# --- Main ---

header "Checking secrets"
echo ""

for env in "${ENVIRONMENTS[@]}"; do
    secrets_dir="$ENVS_DIR/$env/secrets"

    bold "Environment: $env"

    if [ ! -d "$secrets_dir" ]; then
        warn "No secrets directory: $secrets_dir"
        WARNINGS=$((WARNINGS + 1))
        echo ""
        continue
    fi

    for template in "$TEMPLATES_DIR"/*.template.yaml; do
        chart_name=$(basename "$template" .template.yaml)
        enc_file="$secrets_dir/${chart_name}.enc.yaml"
        secrets_file="$secrets_dir/${chart_name}.secrets.yaml"

        # --- Find the secret file ---
        secret_source=""
        temp_file=""

        if [ -f "$enc_file" ]; then
            temp_file=$(mktemp "${TMPDIR:-/tmp}/check-secrets.${chart_name}.XXXXXX")
            if sops --decrypt "$enc_file" > "$temp_file" 2>/dev/null; then
                secret_source="$temp_file"
            else
                error "[$env/$chart_name] Failed to decrypt $enc_file"
                ERRORS=$((ERRORS + 1))
                rm -f "$temp_file"
                continue
            fi
        elif [ -f "$secrets_file" ]; then
            secret_source="$secrets_file"
        else
            error "[$env/$chart_name] Missing secret file (expected ${chart_name}.enc.yaml or ${chart_name}.secrets.yaml)"
            ERRORS=$((ERRORS + 1))
            continue
        fi

        # --- Extract and compare keys ---
        template_keys=$(extract_keys_py "$template")
        secret_keys=$(extract_keys_py "$secret_source")

        # Clean up temp file
        [ -n "$temp_file" ] && rm -f "$temp_file"

        if [ -z "$template_keys" ]; then
            warn "[$env/$chart_name] Could not extract keys from template"
            WARNINGS=$((WARNINGS + 1))
            continue
        fi

        if [ -z "$secret_keys" ]; then
            error "[$env/$chart_name] Could not extract keys from secret file"
            ERRORS=$((ERRORS + 1))
            continue
        fi

        # Compare: find missing keys (in template but not in secret)
        missing_keys=()
        while IFS= read -r key; do
            if ! echo "$secret_keys" | grep -qxF "$key"; then
                missing_keys+=("$key")
            fi
        done <<< "$template_keys"

        # Compare: find extra keys (in secret but not in template)
        extra_keys=()
        while IFS= read -r key; do
            if ! echo "$template_keys" | grep -qxF "$key"; then
                extra_keys+=("$key")
            fi
        done <<< "$secret_keys"

        # --- Report results ---
        if [ ${#missing_keys[@]} -eq 0 ] && [ ${#extra_keys[@]} -eq 0 ]; then
            success "[$env/$chart_name] OK"
        else
            if [ ${#missing_keys[@]} -gt 0 ]; then
                error "[$env/$chart_name] Missing ${#missing_keys[@]} field(s):"
                for key in "${missing_keys[@]}"; do
                    echo "          - $key"
                done
                ERRORS=$((ERRORS + 1))
            fi
            if [ ${#extra_keys[@]} -gt 0 ]; then
                warn "[$env/$chart_name] Extra ${#extra_keys[@]} field(s) not in template:"
                for key in "${extra_keys[@]}"; do
                    echo "          - $key"
                done
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    done

    echo ""
done

# --- Summary ---

if [ "$ERRORS" -gt 0 ]; then
    error "$ERRORS error(s), $WARNINGS warning(s)."
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    warn "All secrets present, $WARNINGS warning(s)."
    exit 0
else
    success "All secrets present and up to date."
    exit 0
fi
