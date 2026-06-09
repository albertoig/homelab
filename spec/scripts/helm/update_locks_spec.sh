#!/usr/bin/env bash

Describe 'scripts/helm/update-locks.sh'

  # ── All environments succeed ─────────────────────────────────────────────────

  Describe 'when helmfile succeeds for all environments'
    Mock gum
      echo "$@"
    End
    Mock helmfile
      echo "$@"
    End

    It 'exits successfully'
      When run bash scripts/helm/update-locks.sh
      The status should be success
      The output should include "=== All lock files updated ==="
    End

    It 'runs helmfile deps for the dev environment'
      When run bash scripts/helm/update-locks.sh
      The status should be success
      The output should include "-e dev deps"
    End

    It 'runs helmfile deps for the prod environment'
      When run bash scripts/helm/update-locks.sh
      The status should be success
      The output should include "-e prod deps"
    End
  End

  # ── One environment fails ────────────────────────────────────────────────────

  Describe 'when helmfile fails for one environment'
    Mock gum
      echo "$@"
    End
    Mock helmfile
      if [[ "$*" == *"-e prod"* ]]; then
        exit 1
      fi
      echo "$@"
    End

    It 'exits with failure'
      When run bash scripts/helm/update-locks.sh
      The status should be failure
      The output should include "Failed environments:"
    End

    It 'still runs helmfile for the remaining environment'
      When run bash scripts/helm/update-locks.sh
      The status should be failure
      The output should include "-e dev deps"
    End

    It 'reports the failed environment in the error summary'
      When run bash scripts/helm/update-locks.sh
      The status should be failure
      The output should include "Failed environments:"
      The output should include "prod"
    End
  End

  # ── All environments fail ────────────────────────────────────────────────────

  Describe 'when helmfile fails for all environments'
    Mock gum
      echo "$@"
    End
    Mock helmfile
      exit 1
    End

    It 'exits with failure'
      When run bash scripts/helm/update-locks.sh
      The status should be failure
      The output should include "Failed environments:"
    End

    It 'reports all failed environments in the error summary'
      When run bash scripts/helm/update-locks.sh
      The status should be failure
      The output should include "Failed environments:"
      The output should include "dev"
      The output should include "prod"
    End
  End
End
