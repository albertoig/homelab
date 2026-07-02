#!/usr/bin/env bash
# Install or update a single helmfile release in isolation, selected by name.
# Usage: ./scripts/helm/install-one.sh [environment] [release]
# Example: ./scripts/helm/install-one.sh dev redis
#
# Unlike scripts/helm/install.sh (which syncs the whole environment), this syncs
# exactly ONE release. Any release the Helmfile DEFINES for the environment is a
# target — already deployed → an update, not yet deployed → a fresh install. A
# release running in the cluster but NOT defined in the Helmfile is never
# selectable — see scripts/lib/helmfile.sh for the YAML-as-source-of-truth guard.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"
export HELMFILE_ROOT="$ROOT_DIR"
source "$SCRIPT_DIR/../lib/helmfile.sh"

# ── Tooling ───────────────────────────────────────────────────────────────────

for tool in gum helmfile helm jq yq; do
    if ! command -v "$tool" &>/dev/null; then
        error "$tool not found. Run: mise install"
        exit 1
    fi
done

# ── Arguments ─────────────────────────────────────────────────────────────────

DRY_RUN=0
ASSUME_YES=0
POSITIONAL=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)  DRY_RUN=1 ;;
        --yes|-y)   ASSUME_YES=1 ;;
        --) shift; while [ "$#" -gt 0 ]; do POSITIONAL+=("$1"); shift; done; break ;;
        -*) error "Unknown option: $1"; exit 1 ;;
        *)  POSITIONAL+=("$1") ;;
    esac
    shift
done
[ -n "${MISE_NONINTERACTIVE:-}" ] && ASSUME_YES=1

# ── Environment selector (arg, ENV var, or prompt) ─────────────────────────────

source "$SCRIPT_DIR/../lib/env.sh" "${POSITIONAL[0]:-}"
RELEASE_ARG="${POSITIONAL[1]:-}"

# ── Banner ────────────────────────────────────────────────────────────────────

show_header
show_subheader "$ENV"

# ── Installable releases (every release DEFINED in YAML; install or update) ────
# `helm list -A` can take ~15s on a busy cluster, so compute the target set ONCE
# and show a spinner — otherwise the screen freezes silently after the banner.

SEL_TMP="$(mktemp)"
trap 'rm -f "$SEL_TMP"' EXIT
export -f helmfile_installable_rows helmfile_defined_releases helmfile_cluster_releases
export HELMFILE_MAIN HELMFILE_ROOT _hf_jq_key

if ! gum spin --spinner pulse --show-error \
        --title "  Loading releases in '$ENV'…" \
        -- bash -c "helmfile_installable_rows '$ENV' > '$SEL_TMP'"; then
    error "Cannot reach the cluster (helm list failed). Check your kube context."
    exit 1
fi

# Rows are "namespace/name<TAB>install|update" — split into parallel structures.
SELECTABLE=()
declare -A ACTION=()
LABELS=()
while IFS=$'\t' read -r key act; do
    [ -z "$key" ] && continue
    SELECTABLE+=("$key")
    ACTION["$key"]="$act"
    LABELS+=("$(printf '%s  (%s)' "$key" "$act")")
done < "$SEL_TMP"

if [ "${#SELECTABLE[@]}" -eq 0 ]; then
    info "No releases are defined in the Helmfile for '$ENV'. Nothing to install."
    exit 0
fi

# ── Resolve the target release ────────────────────────────────────────────────

if [ -z "$RELEASE_ARG" ] && [ "$ASSUME_YES" -eq 1 ]; then
    error "Non-interactive mode (--yes) requires an explicit release name."
    exit 1
fi

if [ -z "$RELEASE_ARG" ]; then
    # No release given — let the operator pick. Read the picker from the
    # controlling terminal when there is one (under `mise run` the task's stdin is
    # not the terminal), mirroring lib/env.sh. The label carries the action; the
    # release key is everything before the "  (action)" suffix.
    _pick_tty=/dev/stdin
    { :</dev/tty; } 2>/dev/null && _pick_tty=/dev/tty
    CHOICE=$(gum choose \
        --header "Select a release to install/update in '$ENV':" \
        --cursor "> " \
        --cursor.foreground "$GUM_PRIMARY" \
        --header.foreground "$GUM_SECONDARY" \
        "${LABELS[@]}" <"$_pick_tty") || { warn "Aborted."; exit 0; }
    unset _pick_tty
    KEY="${CHOICE%%  (*}"
    MATCHES=("$KEY")
else
    MATCHES=()
    for rel in "${SELECTABLE[@]}"; do
        if [ "$rel" = "$RELEASE_ARG" ] || [ "${rel##*/}" = "$RELEASE_ARG" ]; then
            MATCHES+=("$rel")
        fi
    done
fi

if [ "${#MATCHES[@]}" -gt 1 ]; then
    error "'$RELEASE_ARG' matches multiple releases; qualify it as namespace/name:"
    printf '  - %s\n' "${MATCHES[@]}"
    exit 1
fi

if [ "${#MATCHES[@]}" -eq 0 ]; then
    # Not defined in the Helmfile. If it is running in the cluster it is unmanaged
    # and refused; otherwise it is simply unknown.
    mapfile -t LIVE < <(helmfile_cluster_keys)
    is_live=0
    for rel in "${LIVE[@]}"; do
        if [ "$rel" = "$RELEASE_ARG" ] || [ "${rel##*/}" = "$RELEASE_ARG" ]; then
            is_live=1
            break
        fi
    done
    if [ "$is_live" -eq 1 ]; then
        error "'$RELEASE_ARG' is running in the cluster but is not defined in the Helmfile for '$ENV'."
        info "Refusing to touch a release the Helmfile does not manage."
        exit 1
    fi
    error "'$RELEASE_ARG' is not a defined release in '$ENV'."
    info "Only releases defined in the Helmfile can be installed or updated."
    info "Selectable releases:"
    printf '  - %s\n' "${SELECTABLE[@]}"
    exit 1
fi

KEY="${MATCHES[0]}"
NAME="${KEY##*/}"
NAMESPACE="${KEY%%/*}"
ACT="${ACTION[$KEY]:-install}"

# ── Preview ───────────────────────────────────────────────────────────────────

META="$(helmfile_release_meta "$ENV" "$KEY")"
CHART="$(printf '%s' "$META" | cut -f1)"
VERSION="$(printf '%s' "$META" | cut -f2)"

header "Release to $ACT"
msg "  release:   $NAME"
msg "  namespace: $NAMESPACE"
msg "  chart:     ${CHART:-?}"
msg "  version:   ${VERSION:-?}"
msg "  action:    $ACT"
echo ""

# ── Requirements (advisory: the release's own needs:) ──────────────────────────
# `helmfile build` renders every release, so show a spinner while it runs.

REQ_TMP="$(mktemp)"
trap 'rm -f "$SEL_TMP" "$REQ_TMP"' EXIT
export -f helmfile_requirements
gum spin --spinner pulse --show-error \
    --title "  Checking prerequisites…" \
    -- bash -c "helmfile_requirements '$ENV' '$KEY' > '$REQ_TMP'" || true
mapfile -t REQUIRES < "$REQ_TMP"
if [ "${#REQUIRES[@]}" -gt 0 ]; then
    warn "$KEY declares a 'needs:' on these — make sure they are installed first:"
    printf '  - %s\n' "${REQUIRES[@]}"
    echo ""
fi

# ── Dry run stops before any change ────────────────────────────────────────────

if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run — no changes made."
    exit 0
fi

# ── Confirm (prod always requires explicit confirmation, even with --yes) ──────

if [ "$ASSUME_YES" -eq 1 ] && [ "$ENV" != "prod" ]; then
    info "Proceeding non-interactively (--yes)."
else
    CONFIRM_MSG="${ACT^} '$NAME' in '$ENV'?"
    [ "$ENV" = "prod" ] && CONFIRM_MSG="⚠️  PROD — $CONFIRM_MSG"
    if ! gum confirm "$CONFIRM_MSG"; then
        warn "Aborted."
        exit 0
    fi
fi

# ── Sync the single release (no environment-wide sync) ─────────────────────────

header "Syncing $NAME in $ENV"
HF_LOG="$(mktemp)"
trap 'rm -f "$SEL_TMP" "$REQ_TMP" "$HF_LOG"' EXIT
if gum spin --spinner pulse --show-error \
        --title "  Syncing $NAME in $ENV…" \
        -- bash -c "helmfile -f '$ROOT_DIR/helmfile.yaml.gotmpl' -e '$ENV' -l name='$NAME' sync --skip-deps > '$HF_LOG' 2>&1"; then
    success "Synced '$NAME' in '$ENV'."
else
    error "Sync failed — output follows:"
    gum pager < "$HF_LOG"
    exit 1
fi
