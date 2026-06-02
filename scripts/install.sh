#!/bin/sh
set -e

ENV="${1:-dev}"

if [ -n "$CLOUDFLARE_R2_ACCESS_KEY_ID" ] && [ -n "$CLOUDFLARE_R2_SECRET_ACCESS_KEY" ]; then
  . "$(dirname "$0")/lib/terraform-env.sh"
  terraform -chdir=terraform init -reconfigure
  terraform -chdir=terraform workspace select "$ENV" 2>/dev/null || terraform -chdir=terraform workspace new "$ENV"
  TF_VAR_environment="$ENV" terraform -chdir=terraform apply
  ./scripts/velero-secrets.sh "$ENV"
else
  echo "Skipping Terraform: R2 credentials not set in .mise.local.toml."
fi

./scripts/install-helmfiles.sh "$ENV"
