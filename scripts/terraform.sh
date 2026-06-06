#!/usr/bin/env bash
set -euo pipefail

CMD="$1"
ENV="${2:-dev}"

. "$(dirname "$0")/lib/terraform-env.sh"

terraform -chdir=terraform init -reconfigure
terraform -chdir=terraform workspace select "$ENV" 2>/dev/null || terraform -chdir=terraform workspace new "$ENV"
TF_VAR_environment="$ENV" terraform -chdir=terraform "$CMD"
