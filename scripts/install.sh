#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi

# ── Environment selector ──────────────────────────────────────────────────────

ENV=$(gum choose \
    --header "Select target environment:" \
    --cursor "> " \
    --cursor.foreground 212 \
    --selected.foreground 212 \
    --header.foreground 99 \
    "dev" "prod") || { warn "Aborted."; exit 0; }

# ── Banner ────────────────────────────────────────────────────────────────────

clear

gum style --foreground 212 --bold \
" ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
 ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
 ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
 ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
 ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
 ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝"

gum style --foreground 240 --faint "  kubernetes infrastructure automation"
echo ""
gum style --foreground 99 "  environment → $(gum style --foreground 212 --bold "$ENV")"
echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────

header "Prerequisites"
echo ""
"$SCRIPT_DIR/check.sh"
echo ""

# ── Confirm ───────────────────────────────────────────────────────────────────

if ! gum confirm "Deploy the '$ENV' environment?"; then
    warn "Aborted."
    exit 0
fi

echo ""

# ── Step 1: Terraform ─────────────────────────────────────────────────────────

if [ -n "${CLOUDFLARE_R2_ACCESS_KEY_ID:-}" ] && [ -n "${CLOUDFLARE_R2_SECRET_ACCESS_KEY:-}" ]; then
    step 1 2 "Infrastructure (Terraform)"
    echo ""

    . "$SCRIPT_DIR/lib/terraform-env.sh"

    TF_PLAN=$(mktemp --suffix=.tfplan)
    trap "rm -f $TF_PLAN" EXIT

    gum spin \
        --spinner pulse \
        --show-error \
        --title "  Initialising Terraform..." \
        -- terraform -chdir="$ROOT_DIR/terraform" init -reconfigure

    gum log --level info "Initialised."

    gum spin \
        --spinner pulse \
        --show-error \
        --title "  Selecting workspace '$ENV'..." \
        -- bash -c "
            terraform -chdir='$ROOT_DIR/terraform' workspace select '$ENV' 2>/dev/null \
                || terraform -chdir='$ROOT_DIR/terraform' workspace new '$ENV'
        "

    gum log --level info "Workspace: $ENV"

    gum spin \
        --spinner pulse \
        --show-error \
        --title "  Planning changes..." \
        -- bash -c "TF_VAR_environment='$ENV' terraform -chdir='$ROOT_DIR/terraform' plan -out='$TF_PLAN'"

    gum log --level info "Plan ready."
    echo ""

    TF_SHOW=$(terraform -chdir="$ROOT_DIR/terraform" show -no-color "$TF_PLAN" 2>/dev/null)
    ADDED=$(    echo "$TF_SHOW" | grep -c "will be created"   || true)
    CHANGED=$(  echo "$TF_SHOW" | grep -c "will be updated"   || true)
    DESTROYED=$(echo "$TF_SHOW" | grep -c "will be destroyed" || true)

    ADD_ARGS=(); CHANGE_ARGS=(); DESTROY_ARGS=()
    while IFS= read -r line; do
        id=$(echo "$line" | awk '{print $2}')
        case "$line" in
            *"will be created"*)   ADD_ARGS+=("$id")     ;;
            *"will be updated"*)   CHANGE_ARGS+=("$id")  ;;
            *"will be destroyed"*) DESTROY_ARGS+=("$id") ;;
        esac
    done < <(echo "$TF_SHOW" | grep "^  # ")

    [ ${#ADD_ARGS[@]}     -eq 0 ] && ADD_ARGS=("none")
    [ ${#CHANGE_ARGS[@]}  -eq 0 ] && CHANGE_ARGS=("none")
    [ ${#DESTROY_ARGS[@]} -eq 0 ] && DESTROY_ARGS=("none")

    BOX_W=$(( (TERM_COLS - 28) / 3 ))
    [ "$BOX_W" -lt 24 ] && BOX_W=24

    ADD_BOX=$(gum style \
        --border rounded --border-foreground 2 \
        --padding "1 2" --width "$BOX_W" \
        -- "+ to add ($ADDED)" "" "${ADD_ARGS[@]}")

    CHANGE_BOX=$(gum style \
        --border rounded --border-foreground 214 \
        --padding "1 2" --width "$BOX_W" \
        -- "~ to change ($CHANGED)" "" "${CHANGE_ARGS[@]}")

    DESTROY_BOX=$(gum style \
        --border rounded --border-foreground 1 \
        --padding "1 2" --width "$BOX_W" \
        -- "- to destroy ($DESTROYED)" "" "${DESTROY_ARGS[@]}")

    gum join --horizontal "$ADD_BOX" " " "$CHANGE_BOX" " " "$DESTROY_BOX"

    echo ""
    if ! gum confirm "Apply this plan to '$ENV'?"; then
        warn "Aborted."
        exit 0
    fi

    TF_LOG=$(mktemp --suffix=.log)
    trap "rm -f $TF_PLAN $TF_LOG" EXIT

    if gum spin \
        --spinner pulse \
        --title "  Applying changes..." \
        -- bash -c "terraform -chdir='$ROOT_DIR/terraform' apply -no-color '$TF_PLAN' > '$TF_LOG' 2>&1"; then
        SUMMARY=$(grep "Apply complete!" "$TF_LOG" || echo "Applied.")
        gum log --level info "$SUMMARY"
    else
        gum log --level error "Apply failed — opening log."
        echo ""
        gum pager < "$TF_LOG"
        exit 1
    fi
    echo ""

    gum spin \
        --spinner pulse \
        --show-error \
        --title "  Writing Velero secrets..." \
        -- "$SCRIPT_DIR/velero-secrets.sh" "$ENV"

    gum log --level info "Velero secrets updated."
    echo ""
else
    step 1 2 "Skipping Terraform — R2 credentials not set in .mise.local.toml."
    echo ""
fi

# ── Step 2: Helmfile sync ─────────────────────────────────────────────────────

step 2 2 "Helm releases (helmfile sync)"
echo ""

HF_LOG=$(mktemp --suffix=.log)
trap "rm -f ${TF_PLAN:-} ${TF_LOG:-} $HF_LOG" EXIT

helmfile -f "$ROOT_DIR/helmfile.yaml.gotmpl" \
    --environment "$ENV" sync --skip-deps > "$HF_LOG" 2>&1 &
HF_PID=$!

FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
FI=0
PREV=""

while kill -0 "$HF_PID" 2>/dev/null; do
    CUR=$(grep -oE "release=[^, ]+" "$HF_LOG" 2>/dev/null | tail -1 | cut -d= -f2 || true)

    if [ -n "$CUR" ] && [ "$CUR" != "$PREV" ]; then
        printf "\r\033[2K"
        [ -n "$PREV" ] && gum log --level info "Installed $PREV"
        PREV="$CUR"
    fi

    printf "\r  %s Installing %s..." "${FRAMES[$FI]}" "${CUR:-releases}"
    FI=$(( (FI + 1) % ${#FRAMES[@]} ))
    sleep 0.1
done

printf "\r\033[2K"

if wait "$HF_PID"; then
    [ -n "$PREV" ] && gum log --level info "Installed $PREV"
    gum log --level info "All releases installed."
else
    gum log --level error "Helmfile sync failed — opening log."
    echo ""
    gum pager < "$HF_LOG"
    exit 1
fi

echo ""

# ── Done ──────────────────────────────────────────────────────────────────────

gum style \
    --border rounded \
    --border-foreground 212 \
    --align center \
    --padding "1 4" \
    --margin "1 2" \
    "$(gum style --foreground 212 --bold "Environment '$ENV' installed.")"
