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

  # ── No-color detection ───────────────────────────────────────────────────────

  Describe 'no-color detection'
    Describe 'when stdout is not a terminal'
      It 'sets _NO_COLOR to 1'
        When call get_var _NO_COLOR
        The output should eq "1"
      End

      It 'sets all ANSI color variables to empty strings'
        check_ansi_empty() {
          source "scripts/lib/colors.sh"
          printf '%s' "${_C_RED}${_C_GREEN}${_C_BLUE}${_C_YELLOW}${_C_MAGENTA}${_C_CYAN}${_C_BOLD}${_C_RESET}"
        }
        When call check_ansi_empty
        The output should eq ""
      End
    End

    Describe 'when NO_COLOR env var is set'
      It 'sets _NO_COLOR to 1'
        check_no_color_env() {
          NO_COLOR=1
          source "scripts/lib/colors.sh"
          printf '%s' "$_NO_COLOR"
        }
        When call check_no_color_env
        The output should eq "1"
      End

      It 'sets ANSI color variables to empty strings'
        check_ansi_no_color() {
          NO_COLOR=1
          source "scripts/lib/colors.sh"
          printf '%s' "${_C_RED}${_C_BOLD}${_C_RESET}"
        }
        When call check_ansi_no_color
        The output should eq ""
      End
    End
  End

  # ── Log functions ────────────────────────────────────────────────────────────
  # Tests run in non-TTY context so ANSI vars are always empty — output is plain text.

  Describe 'log functions'
    It 'info outputs [INFO] and the message'
      When call call_log info "something happened"
      The output should eq "  [INFO] something happened"
    End

    It 'success outputs [OK] and the message'
      When call call_log success "all good"
      The output should eq "  [OK] all good"
    End

    It 'error outputs [ERROR] and the message'
      When call call_log error "something broke"
      The output should eq "  [ERROR] something broke"
    End

    It 'warn outputs [WARN] and the message'
      When call call_log warn "be careful"
      The output should eq "  [WARN] be careful"
    End

    It 'step outputs [N/M] and the message'
      When call call_log step 2 5 "running step"
      The output should eq "  [2/5] running step"
    End

    It 'header wraps the message with === markers'
      When call call_log header "My Section"
      The output should eq "=== My Section ==="
    End

    It 'msg outputs text as-is'
      When call call_log msg "plain text"
      The output should eq "plain text"
    End

    It 'bold outputs text'
      When call call_log bold "bold text"
      The output should eq "bold text"
    End
  End
End
