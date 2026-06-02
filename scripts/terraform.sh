#!/bin/sh
set -e

CMD="$1"
ENV="${2:-dev}"

. "$(dirname "$0")/lib/terraform-env.sh"

TF_WORKSPACE="$ENV" terraform -chdir=terraform init -reconfigure
TF_WORKSPACE="$ENV" TF_VAR_environment="$ENV" terraform -chdir=terraform "$CMD"
