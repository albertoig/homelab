#!/bin/sh
set -e

CMD="$1"
ENV="${2:-dev}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

. "$(dirname "$0")/../lib/terraform-env.sh"

terraform -chdir="$REPO_ROOT/terraform" init -reconfigure
terraform -chdir="$REPO_ROOT/terraform" workspace select "$ENV" 2>/dev/null || terraform -chdir="$REPO_ROOT/terraform" workspace new "$ENV"
TF_VAR_environment="$ENV" terraform -chdir="$REPO_ROOT/terraform" "$CMD"
