#!/usr/bin/env bash

Describe 'scripts/lib/env.sh'
  # Sources env.sh inside a command substitution so that any exit call from the
  # sourced script exits that inner subshell instead of aborting the test.
  # The resulting ENV value is printed and captured by shellspec.
  source_env() {
    local _output _status
    _output=$(source "scripts/lib/env.sh" "$@"; echo "$ENV")
    _status=$?
    echo "$_output"
    return "$_status"
  }

  # Verifies _sel_arg is not leaked into the caller's scope after sourcing.
  # Uses a direct source (no inner subshell) since "dev" never calls exit 1.
  cleanup_check() {
    _sel_arg="before"
    source "scripts/lib/env.sh" "dev"
    if [ -z "${_sel_arg+x}" ]; then echo "cleaned"; else echo "leaked: $_sel_arg"; fi
  }

  Describe 'with an explicit argument'
    It 'accepts "dev" and sets ENV'
      When call source_env "dev"
      The output should eq "dev"
      The status should be success
    End

    It 'accepts "prod" and sets ENV'
      When call source_env "prod"
      The output should eq "prod"
      The status should be success
    End

    It 'rejects an unknown environment with exit 1'
      Mock gum
        :
      End
      When call source_env "staging"
      The output should eq ""
      The status should be failure
    End

    It 'rejects "production" (only exact values are accepted)'
      Mock gum
        :
      End
      When call source_env "production"
      The output should eq ""
      The status should be failure
    End

    It 'cleans up _sel_arg after sourcing'
      When call cleanup_check
      The output should eq "cleaned"
    End
  End

  Describe 'without an argument (interactive gum prompt)'
    It 'sets ENV to the environment chosen in gum'
      Mock gum
        case "$1" in
          choose) echo "dev" ;;
        esac
      End
      When call source_env
      The output should eq "dev"
      The status should be success
    End

    It 'accepts prod from gum selection'
      Mock gum
        case "$1" in
          choose) echo "prod" ;;
        esac
      End
      When call source_env
      The output should eq "prod"
      The status should be success
    End

    It 'exits 0 and outputs nothing when the user aborts gum'
      Mock gum
        case "$1" in
          choose) exit 1 ;;
        esac
      End
      Mock warn
        :
      End
      When call source_env
      The status should be success
      The output should eq ""
    End

    It 'exits 1 when gum returns an invalid environment name'
      Mock gum
        case "$1" in
          choose) echo "invalid" ;;
          log)    :             ;;
        esac
      End
      When call source_env
      The output should eq ""
      The status should be failure
    End
  End
End
