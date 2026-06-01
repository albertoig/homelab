#!/bin/bash
# Maps CLOUDFLARE_* variables from .mise.local.toml to the standard environment
# variables that Terraform's S3 backend reads natively for Cloudflare R2.
#
# Usage: source scripts/lib/terraform-env.sh

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ] || [ -z "$CLOUDFLARE_R2_ACCESS_KEY_ID" ] || [ -z "$CLOUDFLARE_R2_SECRET_ACCESS_KEY" ]; then
  echo "Error: CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_R2_ACCESS_KEY_ID, and CLOUDFLARE_R2_SECRET_ACCESS_KEY must be set in .mise.local.toml"
  return 1
fi

export AWS_ENDPOINT_URL_S3="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
export AWS_ACCESS_KEY_ID="$CLOUDFLARE_R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$CLOUDFLARE_R2_SECRET_ACCESS_KEY"
export TF_VAR_cloudflare_account_id="$CLOUDFLARE_ACCOUNT_ID"
