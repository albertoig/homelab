#!/usr/bin/env bash
# Cluster doctor: diagnoses common homelab failure patterns.
# Diagnose-only by default; --fix applies remediations after confirmation.
#
# Boxes:
#   Services  every service                  (fixable: strip stuck finalizers)
#   Pods      every workload with pod count  (fixable: delete stuck/failed pods)
#   Storage   every PVC and its service      (fixable: delete stuck attachments)
#   Platform  helm releases, nodes, OpenBao  (report only)
#
# Usage: ./scripts/infra/doctor.sh [environment] [--fix] [--yes]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/header.sh"

FIX=0
YES=0
ENV_ARG=""
for arg in "$@"; do
    case "$arg" in
        dev|prod) ENV_ARG="$arg" ;;
        --fix) FIX=1 ;;
        --yes|-y) YES=1 ;;
        *) echo "Usage: $0 [dev|prod] [--fix] [--yes]" >&2; exit 2 ;;
    esac
done

if ! command -v gum &>/dev/null; then
    error "gum not found. Run: mise install"
    exit 1
fi
if ! command -v kubectl &>/dev/null; then
    error "kubectl not found. Run: mise install"
    exit 1
fi

source "$SCRIPT_DIR/../lib/env.sh" "$ENV_ARG"
KUBE_CONTEXT="homelab-$ENV"

# All cluster reads/writes target the selected environment's context
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }

show_header
gum_secondary "  cluster doctor — env → $(gum_primary --bold "$ENV")$( [ "$FIX" -eq 1 ] && gum_accent ' — fix mode' )"
echo ""

# Pods/services older than this are considered stuck, not merely slow
STUCK_SECONDS="${DOCTOR_STUCK_SECONDS:-180}"
ISSUES=0

CLUSTER_LINES=""
PLATFORM_LINES=""
HINTS=()
FIXES=()

ok_mark()  { gum_success --bold '✓'; }
bad_mark() { gum_error --bold '✗'; }

append_line() {
    local -n _box="$1"
    _box="${_box:+${_box}$'\n'}  $2"
}

# ── Services: one summary line, items shown only when stuck ──────────────────

gather_services() {
    local json total
    json=$(k get svc -A -o json 2>/dev/null || echo '{"items":[]}')
    total=$(jq '.items | length' <<<"$json")

    local stuck=()
    mapfile -t stuck < <(jq -r --argjson t "$STUCK_SECONDS" '
        .items[]
        | select(.metadata.deletionTimestamp != null)
        | select((.metadata.finalizers // []) | length > 0)
        | select((now - (.metadata.deletionTimestamp | fromdateiso8601)) > $t)
        | "\(.metadata.namespace)/\(.metadata.name)"' <<<"$json")

    if [ ${#stuck[@]} -eq 0 ]; then
        append_line CLUSTER_LINES "$(ok_mark)  services / $total healthy"
        return
    fi
    local svc
    for svc in "${stuck[@]}"; do
        append_line CLUSTER_LINES "$(bad_mark)  services / $svc — stuck terminating"
        ISSUES=$((ISSUES + 1))
        FIXES+=("svcfin|${svc%%/*}|${svc#*/}")
    done
}

# ── Pods: one summary line, items shown only when stuck or failed ────────────

gather_pods() {
    local json total
    json=$(k get pods -A -o json 2>/dev/null || echo '{"items":[]}')
    total=$(jq '.items | length' <<<"$json")

    local stuck=() failed=()
    mapfile -t stuck < <(jq -r --argjson t "$STUCK_SECONDS" '
        .items[]
        | select(.status.phase == "Pending")
        | select((now - (.metadata.creationTimestamp | fromdateiso8601)) > $t)
        | "\(.metadata.namespace)/\(.metadata.name)"' <<<"$json")
    mapfile -t failed < <(jq -r '
        .items[]
        | select(.status.phase == "Failed")
        | "\(.metadata.namespace)/\(.metadata.name) (\(.status.reason // "Failed"))"' <<<"$json")

    if [ ${#stuck[@]} -eq 0 ] && [ ${#failed[@]} -eq 0 ]; then
        append_line CLUSTER_LINES "$(ok_mark)  pods / $total running"
        return
    fi
    local pod entry
    for pod in "${stuck[@]+"${stuck[@]}"}"; do
        append_line CLUSTER_LINES "$(bad_mark)  pods / $pod — stuck Pending"
        ISSUES=$((ISSUES + 1))
        FIXES+=("podforce|${pod%%/*}|${pod#*/}")
    done
    for entry in "${failed[@]+"${failed[@]}"}"; do
        pod="${entry%% (*}"
        append_line CLUSTER_LINES "$(bad_mark)  pods / $entry — failed"
        ISSUES=$((ISSUES + 1))
        FIXES+=("poddel|${pod%%/*}|${pod#*/}")
    done
}

# ── Storage: one summary line, volumes shown only when unhealthy ─────────────

gather_storage() {
    local pvc_json va_json pv_json total
    pvc_json=$(k get pvc -A -o json 2>/dev/null || echo '{"items":[]}')
    va_json=$(k get volumeattachments -o json 2>/dev/null || echo '{"items":[]}')
    pv_json=$(k get pv -o json 2>/dev/null || echo '{"items":[]}')
    total=$(jq '.items | length' <<<"$pvc_json")

    local pending=() stuck_vas=()
    mapfile -t pending < <(jq -r '
        .items[]
        | select(.status.phase == "Pending")
        | "\(.metadata.namespace)/\(.metadata.name)"' <<<"$pvc_json")
    mapfile -t stuck_vas < <(jq -r --argjson t "$STUCK_SECONDS" '
        .items[]
        | select(.metadata.deletionTimestamp != null)
        | select((now - (.metadata.deletionTimestamp | fromdateiso8601)) > $t)
        | [ .metadata.name, (.spec.source.persistentVolumeName // "") ]
        | @tsv' <<<"$va_json")

    if [ ${#pending[@]} -eq 0 ] && [ ${#stuck_vas[@]} -eq 0 ]; then
        append_line CLUSTER_LINES "$(ok_mark)  volumes / $total bound"
        return
    fi
    local pvc va pv claim
    for pvc in "${pending[@]+"${pending[@]}"}"; do
        append_line CLUSTER_LINES "$(bad_mark)  volumes / $pvc — Pending"
        ISSUES=$((ISSUES + 1))
    done
    while IFS=$'\t' read -r va pv; do
        [ -n "$va" ] || continue
        # Resolve the PV claim so the line names the volume's service
        claim=$(jq -r --arg pv "$pv" '
            .items[] | select(.metadata.name == $pv)
            | .spec.claimRef.name // empty' <<<"$pv_json")
        append_line CLUSTER_LINES "$(bad_mark)  volumes / ${claim:-unknown} / $va — stuck detaching"
        ISSUES=$((ISSUES + 1))
        FIXES+=("vadel||$va")
    done < <(printf '%s\n' "${stuck_vas[@]+"${stuck_vas[@]}"}")
}

# ── Platform: helm releases, nodes, OpenBao ───────────────────────────────────

gather_platform() {
    # Helm releases
    if command -v helm &>/dev/null; then
        local json total ns name status
        json=$(helm list --kube-context "$KUBE_CONTEXT" -A -o json 2>/dev/null || echo '[]')
        total=$(jq 'length' <<<"$json")
        local bad=()
        mapfile -t bad < <(jq -r '
            .[]
            | select(.status != "deployed" and .status != "superseded")
            | [.namespace, .name, .status] | @tsv' <<<"$json")
        if [ ${#bad[@]} -eq 0 ]; then
            append_line PLATFORM_LINES "$(ok_mark)  helm / $total releases deployed"
        else
            while IFS=$'\t' read -r ns name status; do
                [ -n "$name" ] || continue
                append_line PLATFORM_LINES "$(bad_mark)  helm / $ns/$name ($status)"
                ISSUES=$((ISSUES + 1))
                HINTS+=("$ns/$name is $status — fix manually: helm rollback $name -n $ns, or re-run mise run install")
            done < <(printf '%s\n' "${bad[@]}")
        fi
    fi

    # Nodes
    local json total node cond
    json=$(k get nodes -o json 2>/dev/null || echo '{"items":[]}')
    total=$(jq '.items | length' <<<"$json")
    local bad_nodes=()
    mapfile -t bad_nodes < <(jq -r '
        .items[] | . as $n
        | .status.conditions[]?
        | select((.type == "Ready" and .status != "True")
                 or ((.type | test("Pressure")) and .status == "True"))
        | "\($n.metadata.name) — \(.type)=\(.status)"' <<<"$json")
    if [ ${#bad_nodes[@]} -eq 0 ]; then
        append_line PLATFORM_LINES "$(ok_mark)  nodes / $total ready"
    else
        for cond in "${bad_nodes[@]}"; do
            append_line PLATFORM_LINES "$(bad_mark)  nodes / $cond"
            ISSUES=$((ISSUES + 1))
        done
    fi

    # OpenBao seal status
    if ! k get pod openbao-0 -n openbao-system &>/dev/null; then
        append_line PLATFORM_LINES "$(ok_mark)  openbao / not deployed — skipped"
        return
    fi
    local sealed
    sealed=$(k exec -n openbao-system openbao-0 -- \
        env BAO_ADDR=http://127.0.0.1:8200 bao status -format=json 2>/dev/null \
        | jq -r '.sealed' 2>/dev/null || echo "")
    case "$sealed" in
        false)
            append_line PLATFORM_LINES "$(ok_mark)  openbao / unsealed"
            ;;
        true)
            append_line PLATFORM_LINES "$(bad_mark)  openbao / SEALED"
            ISSUES=$((ISSUES + 1))
            HINTS+=("openbao is sealed and ESO secret syncing is stopped — unseal with 3 keys: kubectl exec -n openbao-system openbao-0 -- bao operator unseal")
            ;;
        *)
            append_line PLATFORM_LINES "$(bad_mark)  openbao / status unknown"
            ISSUES=$((ISSUES + 1))
            HINTS+=("openbao pod exists but 'bao status' failed — check: kubectl logs -n openbao-system openbao-0")
            ;;
    esac
}

# ── Gather ────────────────────────────────────────────────────────────────────

# Single-line progress bar with a braille spinner, animated by a background
# process while each gather step runs; TTY only so captured/test output stays
# clean. State (completed steps + label) is handed over through a temp file.
PROGRESS_TOTAL=4
PROGRESS_STATE=""
PROGRESS_PID=""
SPINNER_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

progress_start() {
    [[ -t 1 ]] || return 0
    PROGRESS_STATE=$(mktemp)
    echo "0 starting…" > "$PROGRESS_STATE"
    (
        i=0
        width=28
        while :; do
            read -r step label < "$PROGRESS_STATE" 2>/dev/null || { step=0; label=""; }
            filled=$((width * step / PROGRESS_TOTAL))
            bar=""
            for ((j = 0; j < filled; j++)); do bar+="█"; done
            for ((j = filled; j < width; j++)); do bar+="░"; done
            frame="${SPINNER_FRAMES:i % 10:1}"
            printf '\r  \033[38;5;%sm%s\033[0m \033[1;38;5;%sm%s\033[0m \033[2;38;5;%sm%s\033[0m\033[K' \
                "$GUM_PRIMARY" "$bar" "$GUM_ACCENT" "$frame" "$GUM_MUTED" "$label"
            i=$((i + 1))
            sleep 0.08
        done
    ) &
    PROGRESS_PID=$!
}

progress() {
    [ -n "$PROGRESS_STATE" ] || return 0
    echo "$1 $2" > "$PROGRESS_STATE"
}

progress_done() {
    if [ -n "$PROGRESS_PID" ]; then
        kill "$PROGRESS_PID" 2>/dev/null || true
        wait "$PROGRESS_PID" 2>/dev/null || true
    fi
    [ -n "$PROGRESS_STATE" ] && rm -f "$PROGRESS_STATE"
    PROGRESS_PID=""
    PROGRESS_STATE=""
    [[ -t 1 ]] && printf '\r\033[K'
    return 0
}
trap progress_done EXIT

progress_start
progress 0 "checking services…"
gather_services
progress 1 "checking pods…"
gather_pods
progress 2 "checking storage…"
gather_storage
progress 3 "checking platform…"
gather_platform
progress_done

# ── Render boxes ──────────────────────────────────────────────────────────────

[ -n "$CLUSTER_LINES" ]  || CLUSTER_LINES="  (none)"
[ -n "$PLATFORM_LINES" ] || PLATFORM_LINES="  (none)"

# Pad the shorter column so paired boxes render at the same height
pad_pair() {
    local -n _a="$1" _b="$2"
    local na nb
    na=$(awk 'END { print NR }' <<<"$_a")
    nb=$(awk 'END { print NR }' <<<"$_b")
    while [ "$na" -lt "$nb" ]; do _a+=$'\n'; na=$((na + 1)); done
    while [ "$nb" -lt "$na" ]; do _b+=$'\n'; nb=$((nb + 1)); done
}

render_box() {
    gum style \
        --border rounded \
        --border-foreground "$GUM_SECONDARY" \
        --padding "1 2" \
        "$(gum_secondary --bold "$1")" \
        "" \
        "$2"
}

pad_pair CLUSTER_LINES PLATFORM_LINES

gum join --horizontal \
    "$(render_box 'Cluster' "$CLUSTER_LINES")" "   " \
    "$(render_box 'Platform' "$PLATFORM_LINES")"
echo ""

for hint in "${HINTS[@]+"${HINTS[@]}"}"; do
    gum_muted "  → $hint"
done
[ ${#HINTS[@]} -gt 0 ] && echo ""

# ── Fix phase ─────────────────────────────────────────────────────────────────

confirm_fix() {
    [ "$YES" -eq 1 ] && return 0
    gum confirm "  $1"
}

if [ "$FIX" -eq 1 ] && [ ${#FIXES[@]} -gt 0 ]; then
    for fix in "${FIXES[@]}"; do
        IFS='|' read -r kind ns name <<<"$fix"
        case "$kind" in
            svcfin)
                if confirm_fix "Strip finalizers from service $ns/$name?"; then
                    k patch svc "$name" -n "$ns" --type=merge \
                        -p '{"metadata":{"finalizers":[]}}'
                    info "Stripped finalizers from $ns/$name"
                fi
                ;;
            podforce)
                # Events usually name the root cause (volume attach, scheduling)
                k get events -n "$ns" \
                    --field-selector "involvedObject.name=$name" \
                    --sort-by=.lastTimestamp 2>/dev/null | tail -3 | while IFS= read -r ev; do
                    gum_muted "       $ev"
                done
                if confirm_fix "Force delete pod $ns/$name?"; then
                    k delete pod "$name" -n "$ns" --force --grace-period=0
                    info "Force deleted $ns/$name"
                fi
                ;;
            poddel)
                if confirm_fix "Delete failed pod $ns/$name?"; then
                    k delete pod "$name" -n "$ns"
                    info "Deleted $ns/$name"
                fi
                ;;
            vadel)
                if confirm_fix "Delete stuck VolumeAttachment $name?"; then
                    k delete volumeattachment "$name"
                    info "Deleted $name"
                fi
                ;;
        esac
    done
    echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────

if [ "$ISSUES" -eq 0 ]; then
    gum style \
        --border double \
        --border-foreground "$GUM_SUCCESS" \
        --padding "1 4" \
        --margin "0 1" \
        --bold \
        "$(gum_success --bold "✓  Cluster looks healthy.")"
    exit 0
fi

HINT=""
[ "$FIX" -eq 0 ] && HINT=" Re-run with: mise run doctor -- $ENV --fix"
gum style \
    --border rounded \
    --border-foreground "$GUM_ERROR" \
    --padding "0 2" \
    "$(gum_error --bold "$ISSUES issue(s) found.")$HINT"
exit 1
