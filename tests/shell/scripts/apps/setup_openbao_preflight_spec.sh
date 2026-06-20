#!/usr/bin/env bash

Describe 'scripts/apps/setup-openbao-preflight.sh'

  # The script discovers tools with `command -v`, so shellspec Mock (which only
  # prepends to PATH) cannot simulate a *missing* tool. Each run instead gets a
  # sandbox bin dir as its entire PATH: stubs for the tools it checks, symlinks
  # for the real utilities it needs (bash, dirname), and nothing else. Removing a
  # stub makes that tool genuinely absent.
  #
  # kubectl behaviour is driven by environment variables, one per resource the
  # script verifies; setting a variable to 1 makes that single kubectl call fail:
  #   CHECKSPEC_K8S_FAIL        `kubectl cluster-info`
  #   CHECKSPEC_NO_OPENBAO_NS   `get namespace openbao-system`
  #   CHECKSPEC_NO_POD          `get pod openbao-0`
  #   CHECKSPEC_NO_ESO_NS       `get namespace external-secrets-system`
  #   CHECKSPEC_NO_CRD          `get crd clustersecretstores.external-secrets.io`
  #
  # Runs in quiet mode so the banner / clear are skipped — the same way
  # setup-openbao.sh invokes it.

  make_sandbox() {
    local bin="$1" tool real

    # gum: `spin` executes the wrapped command and propagates its exit status;
    # `choose` (env.sh prompt) returns dev; everything else prints its arguments.
    cat > "$bin/gum" <<'EOF'
#!/bin/bash
if [ "$1" = "spin" ]; then
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
  shift
  exec "$@"
fi
if [ "$1" = "choose" ]; then
  echo "dev"
  exit 0
fi
echo "$*"
EOF

    # env.sh routes every check through `--context homelab-<env>`; drop that
    # leading flag pair so the resource matching below stays simple.
    cat > "$bin/kubectl" <<'EOF'
#!/bin/bash
[ "$1" = "--context" ] && shift 2
case "$1" in
  cluster-info)
    [ "${CHECKSPEC_K8S_FAIL:-0}" = "1" ] && exit 1 ;;
  get)
    case "$2 $3" in
      "namespace openbao-system")
        [ "${CHECKSPEC_NO_OPENBAO_NS:-0}" = "1" ] && exit 1 ;;
      "pod openbao-0")
        [ "${CHECKSPEC_NO_POD:-0}" = "1" ] && exit 1 ;;
      "namespace external-secrets-system")
        [ "${CHECKSPEC_NO_ESO_NS:-0}" = "1" ] && exit 1 ;;
      "crd clustersecretstores.external-secrets.io")
        [ "${CHECKSPEC_NO_CRD:-0}" = "1" ] && exit 1 ;;
    esac ;;
esac
exit 0
EOF

    printf '#!/bin/bash\nexit 0\n' > "$bin/jq"

    chmod +x "$bin"/*

    # Real utilities the script needs, symlinked after chmod so it skips them
    for real in bash dirname; do
      ln -s "$(command -v "$real")" "$bin/$real"
    done
  }

  run_check() {
    local bin status
    bin=$(mktemp -d)
    make_sandbox "$bin"
    PATH="$bin" OPENBAO_PREFLIGHT_QUIET=1 bash scripts/apps/setup-openbao-preflight.sh "$@"
    status=$?
    rm -rf "$bin"
    return "$status"
  }

  # ── Happy path ───────────────────────────────────────────────────────────────

  Describe 'when every tool and resource is present'
    check_ok() { run_check dev; }

    It 'exits successfully'
      When call check_ok
      The status should be success
      The output should include "Preflight checks passed."
    End

    It 'reports each tool and resource individually'
      When call check_ok
      The status should be success
      The output should include "cli / gum"
      The output should include "cli / kubectl"
      The output should include "cli / jq"
      The output should include "k8s / cluster connection"
      The output should include "openbao / openbao-system namespace"
      The output should include "openbao / openbao-0 pod"
      The output should include "eso / external-secrets-system namespace"
      The output should include "eso / ClusterSecretStore CRD"
      The output should not include "✗"
    End
  End

  # ── Environment selection ────────────────────────────────────────────────────

  Describe 'when no environment argument is given'
    check_prompt() { run_check; }

    It 'falls back to the interactive selector and checks that environment'
      When call check_prompt
      The status should be success
      The output should include "OpenBao setup preflight"
      The output should include "Preflight checks passed."
    End
  End

  Describe 'with an invalid environment'
    check_invalid() { run_check staging; }

    It 'exits with failure'
      When call check_invalid
      The status should be failure
      The output should include "Invalid environment"
    End
  End

  # ── Missing CLI tools ────────────────────────────────────────────────────────

  Describe 'when jq is missing'
    check_no_jq() {
      local bin status
      bin=$(mktemp -d)
      make_sandbox "$bin"
      rm -f "$bin/jq"
      PATH="$bin" OPENBAO_PREFLIGHT_QUIET=1 bash scripts/apps/setup-openbao-preflight.sh dev
      status=$?
      rm -rf "$bin"
      return "$status"
    }

    It 'fails and marks jq as missing'
      When call check_no_jq
      The status should be failure
      The output should include "✗  cli / jq"
      The output should include "1 check(s) failed."
    End
  End

  # ── Cluster connectivity ─────────────────────────────────────────────────────

  Describe 'when the cluster is unreachable'
    check_k8s_down() { CHECKSPEC_K8S_FAIL=1 run_check dev; }

    It 'fails the cluster connection line'
      When call check_k8s_down
      The status should be failure
      The output should include "✗  k8s / cluster connection"
    End
  End

  # ── Missing OpenBao deployment ───────────────────────────────────────────────

  Describe 'when the openbao namespace is absent'
    check_no_ns() { CHECKSPEC_NO_OPENBAO_NS=1 run_check dev; }

    It 'fails the namespace line'
      When call check_no_ns
      The status should be failure
      The output should include "✗  openbao / openbao-system namespace"
    End
  End

  Describe 'when the openbao pod is absent'
    check_no_pod() { CHECKSPEC_NO_POD=1 run_check dev; }

    It 'fails the pod line'
      When call check_no_pod
      The status should be failure
      The output should include "✗  openbao / openbao-0 pod"
    End
  End

  # ── Missing External Secrets Operator ────────────────────────────────────────

  Describe 'when the External Secrets Operator is not installed'
    check_no_eso() { CHECKSPEC_NO_ESO_NS=1 CHECKSPEC_NO_CRD=1 run_check dev; }

    It 'fails both the ESO namespace and the ClusterSecretStore CRD'
      When call check_no_eso
      The status should be failure
      The output should include "✗  eso / external-secrets-system namespace"
      The output should include "✗  eso / ClusterSecretStore CRD"
      The output should include "2 check(s) failed."
    End
  End

  # ── Missing gum ──────────────────────────────────────────────────────────────

  Describe 'when gum itself is missing'
    check_no_gum() {
      local bin status
      bin=$(mktemp -d)
      make_sandbox "$bin"
      rm -f "$bin/gum"
      PATH="$bin" OPENBAO_PREFLIGHT_QUIET=1 bash scripts/apps/setup-openbao-preflight.sh
      status=$?
      rm -rf "$bin"
      return "$status"
    }

    It 'aborts immediately'
      When call check_no_gum
      The status should be failure
      The stderr should be present
    End
  End
End
