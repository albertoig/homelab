#!/usr/bin/env bash

Describe 'scripts/lib/terraform-env.sh'

  # Source the script inside a subshell with the given CF vars set, then print
  # the value of the named exported variable. stderr is suppressed so error
  # messages don't bleed into the output assertion.
  check_export() {
    CLOUDFLARE_ACCOUNT_ID="$1" \
    CLOUDFLARE_R2_ACCESS_KEY_ID="$2" \
    CLOUDFLARE_R2_SECRET_ACCESS_KEY="$3" \
    bash -c "source scripts/lib/terraform-env.sh 2>/dev/null && printf '%s' \"\$$4\""
  }

  # Source the script inside a subshell with the given CF vars set (empty string
  # means unset). Captures stdout (error messages) and returns the exit status.
  try_source() {
    CLOUDFLARE_ACCOUNT_ID="${1:-}" \
    CLOUDFLARE_R2_ACCESS_KEY_ID="${2:-}" \
    CLOUDFLARE_R2_SECRET_ACCESS_KEY="${3:-}" \
    bash -c 'source scripts/lib/terraform-env.sh'
  }

  # ── Happy path ───────────────────────────────────────────────────────────────

  Describe 'with all three variables set'
    It 'builds AWS_ENDPOINT_URL_S3 from the account ID'
      When call check_export "acct123" "key456" "secret789" "AWS_ENDPOINT_URL_S3"
      The output should eq "https://acct123.r2.cloudflarestorage.com"
      The status should be success
    End

    It 'maps CLOUDFLARE_R2_ACCESS_KEY_ID to AWS_ACCESS_KEY_ID'
      When call check_export "acct123" "key456" "secret789" "AWS_ACCESS_KEY_ID"
      The output should eq "key456"
      The status should be success
    End

    It 'maps CLOUDFLARE_R2_SECRET_ACCESS_KEY to AWS_SECRET_ACCESS_KEY'
      When call check_export "acct123" "key456" "secret789" "AWS_SECRET_ACCESS_KEY"
      The output should eq "secret789"
      The status should be success
    End

    It 'maps CLOUDFLARE_ACCOUNT_ID to TF_VAR_cloudflare_account_id'
      When call check_export "acct123" "key456" "secret789" "TF_VAR_cloudflare_account_id"
      The output should eq "acct123"
      The status should be success
    End
  End

  # ── Missing variables ────────────────────────────────────────────────────────

  Describe 'with missing variables'
    It 'fails when CLOUDFLARE_ACCOUNT_ID is unset'
      When call try_source "" "key456" "secret789"
      The status should be failure
      The output should include "CLOUDFLARE_ACCOUNT_ID"
    End

    It 'fails when CLOUDFLARE_R2_ACCESS_KEY_ID is unset'
      When call try_source "acct123" "" "secret789"
      The status should be failure
      The output should include "CLOUDFLARE_R2_ACCESS_KEY_ID"
    End

    It 'fails when CLOUDFLARE_R2_SECRET_ACCESS_KEY is unset'
      When call try_source "acct123" "key456" ""
      The status should be failure
      The output should include "CLOUDFLARE_R2_SECRET_ACCESS_KEY"
    End

    It 'fails when all three variables are unset'
      When call try_source "" "" ""
      The status should be failure
      The output should include "Error:"
    End
  End
End
