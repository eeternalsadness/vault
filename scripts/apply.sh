#!/bin/bash

echo "WARNING: make sure to run this inside the repo's root"
echo "WARNING: make sure to export VAULT_ADDR and VAULT_TOKEN"

# get config env
env="$1"

if [[ -z "$env" ]]; then
  read -rp "Enter env to use [minikube/homelab]: " env
fi

case "$env" in
"minikube") ;;
"homelab") ;;
*)
  echo "Unrecognized input: '${env}'. Input must be 'minikube' or 'homelab'"
  exit 1
  ;;
esac

terraform init -backend-config="envs/${env}/.config/backend-config.conf" -reconfigure
terraform apply -var-file="envs/${env}/.config/terraform.tfvars"
