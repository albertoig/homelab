#!/usr/bin/env bash

Describe 'scripts/lib/colors.sh'
  # Sources colors.sh and prints one variable's value.
  get_var() {
    source "scripts/lib/colors.sh"
    local var="$1"
    printf '%s' "${!var}"
  }

  # Sources colors.sh then calls the named gum wrapper with a fixed argument.
  call_wrapper() {
    source "scripts/lib/colors.sh"
    "$1" "test text"
  }

  # Sources colors.sh then calls a log/utility function with the remaining args.
  call_log() {
    source "scripts/lib/colors.sh"
    "$@"
  }

  # ── Gum palette constants ────────────────────────────────────────────────────

  Describe 'gum palette constants'
    It 'GUM_PRIMARY is 212'
      When call get_var GUM_PRIMARY
      The output should eq "212"
    End

    It 'GUM_SECONDARY is 99'
      When call get_var GUM_SECONDARY
      The output should eq "99"
    End

    It 'GUM_ACCENT is 214'
      When call get_var GUM_ACCENT
      The output should eq "214"
    End

    It 'GUM_SUCCESS is 2'
      When call get_var GUM_SUCCESS
      The output should eq "2"
    End

    It 'GUM_ERROR is 1'
      When call get_var GUM_ERROR
      The output should eq "1"
    End

    It 'GUM_MUTED is 240'
      When call get_var GUM_MUTED
      The output should eq "240"
    End
  End

  # ── Gum wrapper functions ────────────────────────────────────────────────────

  Describe 'gum wrapper functions'
    It 'gum_primary calls gum with --foreground 212'
      Mock gum
        echo "$@"
      End
      When call call_wrapper gum_primary
      The output should include "--foreground 212"
    End

    It 'gum_secondary calls gum with --foreground 99'
      Mock gum
        echo "$@"
      End
      When call call_wrapper gum_secondary
      The output should include "--foreground 99"
    End

    It 'gum_accent calls gum with --foreground 214'
      Mock gum
        echo "$@"
      End
      When call call_wrapper gum_accent
      The output should include "--foreground 214"
    End

    It 'gum_success calls gum with --foreground 2'
      Mock gum
        echo "$@"
      End
      When call call_wrapper gum_success
      The output should include "--foreground 2"
    End

    It 'gum_error calls gum with --foreground 1'
      Mock gum
        echo "$@"
      End
      When call call_wrapper gum_error
      The output should include "--foreground 1"
    End

    It 'gum_muted calls gum with --foreground 240 and --faint'
      Mock gum
        echo "$@"
      End
      When call call_wrapper gum_muted
      The output should include "--foreground 240"
      The output should include "--faint"
    End

    It 'wrappers pass through extra flags to gum'
      Mock gum
        echo "$@"
      End
      call_with_flag() {
        source "scripts/lib/colors.sh"
        gum_primary --bold "text"
      }
      When call call_with_flag
      The output should include "--bold"
      The output should include "--foreground 212"
    End
  End

  # ── Log functions ────────────────────────────────────────────────────────────

  Describe 'log functions'
    It 'info calls gum log with level info'
      Mock gum
        echo "$@"
      End
      When call call_log info "something happened"
      The output should include "--level info"
      The output should include "something happened"
    End

    It 'warn calls gum log with level warn'
      Mock gum
        echo "$@"
      End
      When call call_log warn "be careful"
      The output should include "--level warn"
      The output should include "be careful"
    End

    It 'error calls gum log with level error'
      Mock gum
        echo "$@"
      End
      When call call_log error "something broke"
      The output should include "--level error"
      The output should include "something broke"
    End

    It 'success calls gum log with level info and a check prefix'
      Mock gum
        echo "$@"
      End
      When call call_log success "all good"
      The output should include "--level info"
      The output should include "all good"
    End

    It 'step renders [N/M] label via gum style'
      Mock gum
        echo "$@"
      End
      When call call_log step 2 5 "running step"
      The output should include "[2/5]"
      The output should include "running step"
    End

    It 'header wraps text in === markers via gum style'
      Mock gum
        echo "$@"
      End
      When call call_log header "My Section"
      The output should include "=== My Section ==="
      The output should include "--bold"
    End

    It 'msg outputs text as-is without gum'
      When call call_log msg "plain text"
      The output should eq "plain text"
    End

    It 'bold calls gum_primary with --bold flag'
      Mock gum
        echo "$@"
      End
      When call call_log bold "bold text"
      The output should include "--bold"
      The output should include "bold text"
    End
  End
End
