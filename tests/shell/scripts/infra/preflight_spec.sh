#!/usr/bin/env bash

Describe 'scripts/infra/preflight.sh'

  # preflight.sh discovers tools with `command -v`, so shellspec Mock (which only
  # prepends to PATH) cannot simulate a *missing* tool. Instead each run gets a
  # sandbox bin dir as its entire PATH: stubs for every tool the script checks,
  # symlinks for the real utilities it needs (bash, awk, grep, basename), and
  # nothing else. Removing a stub makes that tool genuinely absent.
  #
  # Stub behaviour is driven by environment variables:
  #   CHECKSPEC_REMOVE        space-separated stubs to delete before running
  #   CHECKSPEC_HELM_PLUGINS  plugin list printed by `helm plugin list`
  #                           (unset = all four expected plugins)
  #   CHECKSPEC_K8S_FAIL      1 = `kubectl cluster-info` exits non-zero

  SPEC_ENV="shellspec-check-env"

  create_fixture_env() {
    mkdir -p "helmfile/environments/$SPEC_ENV/secrets"
    local template chart
    for template in helmfile/secret-templates/*.template.yaml; do
      chart=$(basename "$template" .template.yaml)
      touch "helmfile/environments/$SPEC_ENV/secrets/${chart}.enc.yaml"
    done
  }

  remove_fixture_env() {
    rm -rf "helmfile/environments/$SPEC_ENV"
  }

  BeforeAll 'create_fixture_env'
  AfterAll 'remove_fixture_env'

  make_sandbox() {
    local bin="$1" tool real

    # gum: `spin` executes the wrapped command and propagates its exit status;
    # every other subcommand just prints its arguments
    cat > "$bin/gum" <<'EOF'
#!/bin/bash
if [ "$1" = "spin" ]; then
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done
  shift
  exec "$@"
fi
echo "$*"
EOF

    cat > "$bin/helm" <<'EOF'
#!/bin/bash
if [ "$1" = "plugin" ] && [ "$2" = "list" ]; then
  for p in ${CHECKSPEC_HELM_PLUGINS-secrets secrets-getter secrets-post-renderer diff}; do
    echo "$p"
  done
fi
exit 0
EOF

    cat > "$bin/kubectl" <<'EOF'
#!/bin/bash
if [ "$1" = "config" ] && [ "$2" = "current-context" ]; then
  echo "homelab-prod"
  exit 0
fi
[ "${CHECKSPEC_K8S_FAIL:-0}" = "1" ] && exit 1
exit 0
EOF

    for tool in mise helmfile sops ansible poetry fzf jq yq; do
      printf '#!/bin/bash\nexit 0\n' > "$bin/$tool"
    done

    chmod +x "$bin"/*

    # Real utilities check.sh needs, symlinked after chmod so it skips them
    for real in bash dirname awk grep basename; do
      ln -s "$(command -v "$real")" "$bin/$real"
    done
  }

  run_check() {
    local bin status tool
    bin=$(mktemp -d)
    make_sandbox "$bin"
    for tool in ${CHECKSPEC_REMOVE:-}; do
      rm -f "$bin/$tool"
    done
    PATH="$bin" bash scripts/infra/preflight.sh "$@"
    status=$?
    rm -rf "$bin"
    return "$status"
  }

  # ── Happy path ───────────────────────────────────────────────────────────────

  Describe 'when all tools, plugins, and secrets are present'
    check_ok() { run_check "$SPEC_ENV"; }

    It 'exits successfully'
      When call check_ok
      The status should be success
      The output should include "All checks passed"
    End

    It 'reports every tool, plugin, and the cluster individually'
      When call check_ok
      The status should be success
      The output should include "cli / mise"
      The output should include "cli / kubectl"
      The output should include "cli / yq"
      The output should include "helm / secrets"
      The output should include "helm / diff"
      The output should include "prod / Kubernetes connection"
      The output should not include "✗"
    End

    It 'reports every secret of the environment'
      When call check_ok
      The status should be success
      The output should include "$SPEC_ENV / authentik"
      The output should include "$SPEC_ENV / velero"
    End

    It 'lists each tool exactly once (no duplicated output)'
      count_lines() { check_ok | grep -c "cli / kubectl"; }
      When call count_lines
      The output should eq 1
    End
  End

  # ── Missing CLI tools ────────────────────────────────────────────────────────

  Describe 'when a CLI tool is missing'
    check_no_fzf() { CHECKSPEC_REMOVE="fzf" run_check "$SPEC_ENV"; }

    It 'exits with failure and marks the missing tool'
      When call check_no_fzf
      The status should be failure
      The output should include "✗  cli / fzf"
      The output should include "1 check(s) failed."
    End
  End

  Describe 'when mise is missing'
    check_no_mise() { CHECKSPEC_REMOVE="mise" run_check "$SPEC_ENV"; }

    It 'marks mise as missing'
      When call check_no_mise
      The status should be failure
      The output should include "✗  cli / mise"
    End
  End

  Describe 'when kubectl is missing'
    check_no_kubectl() { CHECKSPEC_REMOVE="kubectl" run_check "$SPEC_ENV"; }

    It 'fails both the tool line and the connection line'
      When call check_no_kubectl
      The status should be failure
      The output should include "✗  cli / kubectl"
      The output should include "✗  cluster / Kubernetes connection"
      The output should include "2 check(s) failed."
    End
  End

  # ── Missing Helm plugins ─────────────────────────────────────────────────────

  Describe 'when a helm plugin is missing'
    check_no_diff() {
      CHECKSPEC_HELM_PLUGINS="secrets secrets-getter secrets-post-renderer" \
        run_check "$SPEC_ENV"
    }

    It 'exits with failure and marks the missing plugin'
      When call check_no_diff
      The status should be failure
      The output should include "✗  helm / diff"
    End
  End

  Describe 'when no helm plugins are installed'
    check_no_plugins() { CHECKSPEC_HELM_PLUGINS="" run_check "$SPEC_ENV"; }

    It 'reports all four plugins as missing'
      When call check_no_plugins
      The status should be failure
      The output should include "✗  helm / secrets"
      The output should include "✗  helm / secrets-getter"
      The output should include "✗  helm / secrets-post-renderer"
      The output should include "✗  helm / diff"
      The output should include "4 check(s) failed."
    End
  End

  # ── Kubernetes connectivity ──────────────────────────────────────────────────

  Describe 'when the cluster is unreachable'
    check_k8s_down() { CHECKSPEC_K8S_FAIL=1 run_check "$SPEC_ENV"; }

    It 'fails the connection line with the context label'
      When call check_k8s_down
      The status should be failure
      The output should include "✗  prod / Kubernetes connection"
      The output should include "1 check(s) failed."
    End
  End

  # ── Missing secrets ──────────────────────────────────────────────────────────

  Describe 'when the environment has no secrets'
    check_empty_env() { run_check "shellspec-no-such-env"; }

    It 'reports every chart secret as missing'
      When call check_empty_env
      The status should be failure
      The output should include "shellspec-no-such-env / authentik"
      The output should include "shellspec-no-such-env / velero"
      The output should include "6 check(s) failed."
    End
  End

  # ── Missing gum ──────────────────────────────────────────────────────────────

  Describe 'when gum itself is missing'
    check_no_gum() { CHECKSPEC_REMOVE="gum" run_check "$SPEC_ENV"; }

    It 'aborts immediately'
      When call check_no_gum
      The status should be failure
      The stderr should be present
    End
  End
End
