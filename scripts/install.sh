#!/bin/sh
set -e

ENV="${1:-dev}"

if [ -n "$CLOUDFLARE_R2_ACCESS_KEY_ID" ] && [ -n "$CLOUDFLARE_R2_SECRET_ACCESS_KEY" ]; then
  . "$(dirname "$0")/lib/terraform-env.sh"
  TF_WORKSPACE="$ENV" terraform -chdir=terraform init -reconfigure
  TF_WORKSPACE="$ENV" TF_VAR_environment="$ENV" terraform -chdir=terraform apply
else
  echo "Skipping Terraform: R2 credentials not set in .mise.local.toml."
fi

./scripts/install-helmfiles.sh "$ENV"
