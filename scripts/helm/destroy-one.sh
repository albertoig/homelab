#!/usr/bin/env bash
# Delete a single helmfile release in isolation, selected by name.
# Usage: ./scripts/helm/destroy-one.sh [environment] [release]
# Example: ./scripts/helm/destroy-one.sh dev redis
#
# Unlike scripts/helm/destroy.sh (which tears down the whole environment), this
# removes exactly one release and runs NO environment-wide cleanup. Only releases
# that are BOTH defined in the Helmfile AND currently deployed are deletable —
# see scripts/lib/helmfile.sh for the YAML-as-source-of-truth guard.

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

POSITIONAL=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --) shift; while [ "$#" -gt 0 ]; do POSITIONAL+=("$1"); shift; done; break ;;
        -*) error "Unknown option: $1"; exit 1 ;;
        *)  POSITIONAL+=("$1") ;;
    esac
    shift
done

# ── Environment selector (arg, ENV var, or prompt) ─────────────────────────────

source "$SCRIPT_DIR/../lib/env.sh" "${POSITIONAL[0]:-}"
RELEASE_ARG="${POSITIONAL[1]:-}"

# ── Banner ────────────────────────────────────────────────────────────────────

show_header
show_subheader "$ENV"

# ── Cluster reachability ──────────────────────────────────────────────────────

if ! helm list -A --output json >/dev/null 2>&1; then
    error "Cannot reach the cluster (helm list failed). Check your kube context."
    exit 1
fi

# ── Selectable releases (defined in YAML AND deployed) ─────────────────────────

mapfile -t SELECTABLE < <(helmfile_selectable_releases "$ENV")

if [ "${#SELECTABLE[@]}" -eq 0 ]; then
    info "No managed releases are currently deployed in '$ENV'. Nothing to delete."
    exit 0
fi

# ── Resolve the target release ────────────────────────────────────────────────

if [ -z "$RELEASE_ARG" ]; then
    # No release given — let the operator pick from the selectable set. Read the
    # picker from the controlling terminal when there is one (under `mise run` the
    # task's stdin is not the terminal), mirroring lib/env.sh.
    _pick_tty=/dev/stdin
    { :</dev/tty; } 2>/dev/null && _pick_tty=/dev/tty
    KEY=$(gum choose \
        --header "Select a release to delete from '$ENV':" \
        --cursor "> " \
        --cursor.foreground "$GUM_PRIMARY" \
        --header.foreground "$GUM_SECONDARY" \
        "${SELECTABLE[@]}" <"$_pick_tty") || { warn "Aborted."; exit 0; }
    unset _pick_tty
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
    # Defined-but-not-deployed is a no-op; anything else is unmanaged and refused.
    mapfile -t DEFINED < <(helmfile_defined_keys "$ENV")
    is_defined=0
    for rel in "${DEFINED[@]}"; do
        if [ "$rel" = "$RELEASE_ARG" ] || [ "${rel##*/}" = "$RELEASE_ARG" ]; then
            is_defined=1
            break
        fi
    done
    if [ "$is_defined" -eq 1 ]; then
        info "'$RELEASE_ARG' is defined but not currently deployed in '$ENV'. Nothing to delete."
        exit 0
    fi
    error "'$RELEASE_ARG' is not a deletable release in '$ENV'."
    info "Only releases defined in the Helmfile AND currently deployed can be deleted."
    info "Selectable releases:"
    printf '  - %s\n' "${SELECTABLE[@]}"
    exit 1
fi

KEY="${MATCHES[0]}"
NAME="${KEY##*/}"
NAMESPACE="${KEY%%/*}"

# ── Preview ───────────────────────────────────────────────────────────────────

META="$(helmfile_release_meta "$ENV" "$KEY")"
CHART="$(printf '%s' "$META" | cut -f1)"
VERSION="$(printf '%s' "$META" | cut -f2)"

header "Release to delete"
msg "  release:   $NAME"
msg "  namespace: $NAMESPACE"
msg "  chart:     ${CHART:-?}"
msg "  version:   ${VERSION:-?}"
echo ""

warn "⚠️  This uninstalls the release and may delete its PersistentVolumes/data."

# ── Confirm (prod always requires explicit confirmation) ───────────────────────

CONFIRM_MSG="Delete release '$NAME' from '$ENV'? This is irreversible."
[ "$ENV" = "prod" ] && CONFIRM_MSG="⚠️  PROD — $CONFIRM_MSG"
if ! gum confirm --default=false "$CONFIRM_MSG"; then
    warn "Aborted."
    exit 0
fi

# ── Delete the single release (no environment-wide cleanup) ────────────────────

header "Deleting $NAME from $ENV"
helmfile -f "$ROOT_DIR/helmfile.yaml.gotmpl" -e "$ENV" -l name="$NAME" destroy --skip-deps
success "Release '$NAME' deleted from '$ENV'."
