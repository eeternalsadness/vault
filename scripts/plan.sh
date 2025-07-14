#!/bin/bash

set -eo pipefail

source "$(dirname $0)/common.sh"

terraform_role="terraform-grafana"

vault_login "$terraform_role"

terraform init -backend-config="$(dirname $0)/../envs/${env}/.config/backend.conf" -reconfigure
terraform plan -var-file="$(dirname $0)/../envs/${env}/.config/terraform.tfvars"
