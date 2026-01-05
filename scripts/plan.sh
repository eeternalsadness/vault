#!/bin/bash

set -eo pipefail

source "$(dirname $0)/common.sh"

terraform_role="terraform-vault"
pg_role="terraform_vault"

vault_login "$terraform_role"
get_pg_creds "$pg_role"

terraform init -backend-config="$(dirname $0)/../envs/${env}/.config/backend.conf" -reconfigure
terraform plan -var-file="$(dirname $0)/../envs/${env}/.config/terraform.tfvars" "$@"
