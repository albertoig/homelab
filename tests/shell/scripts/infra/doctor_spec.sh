#!/usr/bin/env bash

Describe 'scripts/infra/doctor.sh'

  # doctor.sh reads cluster state through kubectl/helm, so each run gets a
  # sandbox bin dir prepended to PATH with stubs that emit fixture JSON from
  # environment variables (empty/healthy by default). Real jq, awk, and date
  # are reached through the rest of PATH; real kubectl/helm/gum are mise-managed
  # and not on /usr/bin, so the stubs always win.
  #
  # Stub behaviour:
  #   DOCTORSPEC_SVCS / _PODS / _VAS / _PVS / _NODES / _PVCS   kubectl get JSON
  #   DOCTORSPEC_HELM                                          helm list JSON
  #   DOCTORSPEC_OPENBAO   1 = openbao-0 pod exists
  #   DOCTORSPEC_BAO       bao status JSON returned via kubectl exec
  #   DOCTORSPEC_CONFIRM   exit code for `gum confirm` (default 0 = yes)
  #   DOCTORSPEC_LOG       file where mutating kubectl calls are appended

  # Fixture timestamps are far in the past so age thresholds always trip
  STUCK_POD='{"items":[{"metadata":{"name":"loki-0","namespace":"monitoring-system","creationTimestamp":"2020-01-01T00:00:00Z"},"status":{"phase":"Pending"}}]}'
  TERM_SVC='{"items":[{"metadata":{"name":"grafana","namespace":"monitoring-system","deletionTimestamp":"2020-01-01T00:00:00Z","finalizers":["service.kubernetes.io/load-balancer-cleanup"]}}]}'
  FAILED_POD='{"items":[{"metadata":{"name":"evicted-1","namespace":"monitoring-system"},"status":{"phase":"Failed","reason":"Evicted"}}]}'
  STALE_VA='{"items":[{"metadata":{"name":"csi-stale-attachment","deletionTimestamp":"2020-01-01T00:00:00Z"},"spec":{"source":{"persistentVolumeName":"pv-123"}}}]}'
  VA_PV='{"items":[{"metadata":{"name":"pv-123"},"spec":{"claimRef":{"name":"data-loki-0"}}}]}'
  BAD_NODE='{"items":[{"metadata":{"name":"node1"},"status":{"conditions":[{"type":"Ready","status":"True"},{"type":"MemoryPressure","status":"True"}]}}]}'
  PENDING_PVC='{"items":[{"metadata":{"name":"data-loki-0","namespace":"monitoring-system"},"status":{"phase":"Pending"}}]}'
  BAD_HELM='[{"name":"grafana","namespace":"monitoring-system","status":"pending-upgrade"}]'

  make_sandbox() {
    local bin="$1"

    cat > "$bin/kubectl" <<'EOF'
#!/bin/bash
orig="$*"
if [ "$1" = "--context" ]; then shift 2; fi
log() { [ -n "${DOCTORSPEC_LOG:-}" ] && echo "$orig" >> "$DOCTORSPEC_LOG"; return 0; }
emit() { if [ -n "$1" ]; then echo "$1"; else echo '{"items":[]}'; fi; }
case "$1" in
  get)
    case "$2" in
      svc)               emit "${DOCTORSPEC_SVCS:-}" ;;
      pods)              emit "${DOCTORSPEC_PODS:-}" ;;
      volumeattachments) emit "${DOCTORSPEC_VAS:-}" ;;
      pv)                emit "${DOCTORSPEC_PVS:-}" ;;
      nodes)             emit "${DOCTORSPEC_NODES:-}" ;;
      pvc)               emit "${DOCTORSPEC_PVCS:-}" ;;
      events)            echo "${DOCTORSPEC_EVENTS:-}" ;;
      pod)               [ "${DOCTORSPEC_OPENBAO:-0}" = "1" ] || exit 1 ;;
    esac
    ;;
  exec)
    echo "${DOCTORSPEC_BAO:-}"
    ;;
  delete|patch)
    log
    ;;
esac
exit 0
EOF

    cat > "$bin/helm" <<'EOF'
#!/bin/bash
if [ "$1" = "list" ]; then
  echo "${DOCTORSPEC_HELM:-[]}"
fi
exit 0
EOF

    cat > "$bin/gum" <<'EOF'
#!/bin/bash
if [ "$1" = "confirm" ]; then
  exit "${DOCTORSPEC_CONFIRM:-0}"
fi
if [ "$1" = "choose" ]; then
  echo "prod"
  exit 0
fi
if [ "$1" = "spin" ]; then
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
  shift
  exec "$@"
fi
echo "$*"
EOF

    chmod +x "$bin"/*
  }

  run_doctor() {
    local bin status
    bin=$(mktemp -d)
    make_sandbox "$bin"
    PATH="$bin:/usr/bin:/bin" bash scripts/infra/doctor.sh "$@"
    status=$?
    rm -rf "$bin"
    return "$status"
  }

  # ── Healthy cluster ──────────────────────────────────────────────────────────

  Describe 'when the cluster is healthy'
    doctor_healthy() { run_doctor prod; }

    It 'reports one general line per area and exits successfully'
      When call doctor_healthy
      The status should be success
      The output should include "Cluster"
      The output should include "Platform"
      The output should include "services /"
      The output should include "pods /"
      The output should include "volumes /"
      The output should include "helm /"
      The output should include "nodes /"
      The output should include "openbao / not deployed"
      The output should include "Cluster looks healthy."
    End
  End

  # ── Environment selection ────────────────────────────────────────────────────

  Describe 'when no environment is given'
    It 'falls back to the interactive selector'
      When call run_doctor
      The status should be success
      The output should include "prod"
      The output should include "Cluster looks healthy."
    End
  End

  Describe 'with an invalid environment'
    It 'exits with usage error'
      When call run_doctor staging
      The status should eq 2
      The stderr should include "Usage:"
    End
  End

  # ── Individual findings ──────────────────────────────────────────────────────

  Describe 'when a pod is stuck Pending'
    doctor_stuck_pod() { DOCTORSPEC_PODS="$STUCK_POD" run_doctor prod; }

    It 'reports the pod and exits with failure'
      When call doctor_stuck_pod
      The status should be failure
      The output should include "pods / monitoring-system/loki-0 — stuck Pending"
      The output should include "1 issue(s) found."
      The output should include "--fix"
    End
  End

  Describe 'when a service is stuck terminating'
    doctor_term_svc() { DOCTORSPEC_SVCS="$TERM_SVC" run_doctor prod; }

    It 'reports the service'
      When call doctor_term_svc
      The status should be failure
      The output should include "services / monitoring-system/grafana — stuck terminating"
    End
  End

  Describe 'when a volume attachment is stuck detaching'
    doctor_stale_va() { DOCTORSPEC_VAS="$STALE_VA" DOCTORSPEC_PVS="$VA_PV" run_doctor prod; }

    It 'reports the attachment with the claim it belongs to'
      When call doctor_stale_va
      The status should be failure
      The output should include "volumes / data-loki-0 / csi-stale-attachment — stuck detaching"
    End
  End

  Describe 'when pods have failed or been evicted'
    doctor_failed_pod() { DOCTORSPEC_PODS="$FAILED_POD" run_doctor prod; }

    It 'reports the pod with its reason, counted once'
      When call doctor_failed_pod
      The status should be failure
      The output should include "pods / monitoring-system/evicted-1 (Evicted) — failed"
      The output should include "1 issue(s) found."
    End
  End

  Describe 'when a helm release is stuck'
    doctor_bad_helm() { DOCTORSPEC_HELM="$BAD_HELM" run_doctor prod; }

    It 'reports the release and suggests a manual fix'
      When call doctor_bad_helm
      The status should be failure
      The output should include "helm / monitoring-system/grafana (pending-upgrade)"
      The output should include "helm rollback"
    End
  End

  Describe 'when a node is under pressure'
    doctor_bad_node() { DOCTORSPEC_NODES="$BAD_NODE" run_doctor prod; }

    It 'reports the node condition'
      When call doctor_bad_node
      The status should be failure
      The output should include "nodes / node1 — MemoryPressure=True"
    End
  End

  Describe 'when a PVC is stuck Pending'
    doctor_pending_pvc() { DOCTORSPEC_PVCS="$PENDING_PVC" run_doctor prod; }

    It 'reports the PVC'
      When call doctor_pending_pvc
      The status should be failure
      The output should include "volumes / monitoring-system/data-loki-0 — Pending"
    End
  End

  Describe 'when OpenBao is sealed'
    doctor_sealed() { DOCTORSPEC_OPENBAO=1 DOCTORSPEC_BAO='{"sealed":true}' run_doctor prod; }

    It 'reports the sealed state with the unseal command'
      When call doctor_sealed
      The status should be failure
      The output should include "SEALED"
      The output should include "bao operator unseal"
    End
  End

  Describe 'when OpenBao is unsealed'
    doctor_unsealed() { DOCTORSPEC_OPENBAO=1 DOCTORSPEC_BAO='{"sealed":false}' run_doctor prod; }

    It 'reports openbao as healthy'
      When call doctor_unsealed
      The status should be success
      The output should include "openbao / unsealed"
    End
  End

  # ── Fix mode ─────────────────────────────────────────────────────────────────

  Describe 'in fix mode with --yes'
    fix_stuck_pod() {
      local log
      log=$(mktemp)
      DOCTORSPEC_PODS="$STUCK_POD" DOCTORSPEC_LOG="$log" \
        run_doctor prod --fix --yes || true
      cat "$log"
      rm -f "$log"
    }

    It 'force deletes the stuck pod against the selected context'
      When call fix_stuck_pod
      The output should include "--context homelab-prod delete pod loki-0 -n monitoring-system --force --grace-period=0"
    End

    fix_term_svc() {
      local log
      log=$(mktemp)
      DOCTORSPEC_SVCS="$TERM_SVC" DOCTORSPEC_LOG="$log" \
        run_doctor prod --fix --yes || true
      cat "$log"
      rm -f "$log"
    }

    It 'strips finalizers from the stuck service'
      When call fix_term_svc
      The output should include "patch svc grafana -n monitoring-system"
      The output should include "finalizers"
    End
  End

  Describe 'in fix mode when the confirmation is declined'
    fix_declined() {
      local log
      log=$(mktemp)
      DOCTORSPEC_PODS="$STUCK_POD" DOCTORSPEC_LOG="$log" DOCTORSPEC_CONFIRM=1 \
        run_doctor prod --fix || true
      cat "$log"
      rm -f "$log"
    }

    It 'does not delete anything'
      When call fix_declined
      The output should not include "delete pod"
    End
  End

  Describe 'in diagnose mode (no --fix)'
    diagnose_only() {
      local log
      log=$(mktemp)
      DOCTORSPEC_PODS="$STUCK_POD" DOCTORSPEC_LOG="$log" \
        run_doctor prod || true
      cat "$log"
      rm -f "$log"
    }

    It 'never mutates the cluster'
      When call diagnose_only
      The output should not include "delete"
      The output should not include "patch"
    End
  End

  # ── Argument validation ──────────────────────────────────────────────────────

  Describe 'with an unknown flag'
    It 'exits with usage error'
      When call run_doctor --bogus
      The status should eq 2
      The stderr should include "Usage:"
    End
  End
End
