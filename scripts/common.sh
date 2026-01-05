#!/bin/bash

set -eo pipefail

function vault_login() {
  local role="$1"
  local mount_path="${2:-oidc-google}"

  if is_vault_token_valid; then
    if is_vault_token_role_valid "$role"; then
      echo "Vault token valid, skipping login"
      return 0
    fi
  fi

  echo "Logging in to Vault using OIDC..."
  local vault_token
  vault_token=$(vault login -method=oidc -path="$mount_path" role="$role" -format=json | jq -r .auth.client_token)
  echo "$vault_token" >"$VAULT_TOKEN_FILE"
  export VAULT_TOKEN="$vault_token"
}

function is_vault_token_valid() {
  echo "Checking Vault token..."

  # check for the token file in the .config file
  if [[ -f "$VAULT_TOKEN_FILE" ]]; then
    local file_token
    file_token=$(<"$VAULT_TOKEN_FILE")
    if VAULT_TOKEN="$file_token" vault token lookup &>/dev/null; then
      return 0
    fi
  fi

  # otherwise check if there's already a token in ~/.vault_token or in the VAULT_TOKEN env
  if vault token lookup &>/dev/null; then
    return 0
  fi

  # If neither works, return failure
  echo "No valid Vault token found."
  return 1
}

function is_vault_token_role_valid() {
  local required_role="$1"

  echo "Checking Vault token's role..."
  local token_role

  # check for the token file in the .config file
  if [[ -f "$VAULT_TOKEN_FILE" ]]; then
    echo "Checking Vault token in '$VAULT_TOKEN_FILE'..."
    local file_token
    file_token=$(<"$VAULT_TOKEN_FILE")
    token_role=$(VAULT_TOKEN="$file_token" vault token lookup -format=json | jq -r '.data.meta.role')
    if [[ "$required_role" == "$token_role" ]]; then
      export VAULT_TOKEN="$file_token"
      return 0
    fi
  fi

  # check existing token if it exists
  token_role=$(vault token lookup -format=json | jq -r '.data.meta.role')
  if [[ "$required_role" != "$token_role" ]]; then
    echo "Token's role '$token_role' doesn't match required role '$required_role'!"
    return 1
  fi

  return 0
}

function consul_get_token() {
  local role="$1"
  local consul_token

  # check for existing token file
  if [[ -f "$CONSUL_LEASE_FILE" ]] && [[ -f "$CONSUL_TOKEN_FILE" ]]; then
    # check if token lease is still valid
    if vault lease lookup $(cat "$CONSUL_LEASE_FILE") &>/dev/null; then
      consul_token=$(cat "$CONSUL_TOKEN_FILE")
      export CONSUL_HTTP_TOKEN="$consul_token"
      return 0
    fi
  fi

  echo "Generating Consul token from Vault..."
  local vault_consul_cred
  vault_consul_cred=$(vault read "consul/creds/${role}" -format=json)

  # write lease id to file for later checks
  jq -r '.lease_id' <<<"$vault_consul_cred" >"$CONSUL_LEASE_FILE"

  # write consul token to file and export to env
  consul_token=$(jq -r '.data.token' <<<"$vault_consul_cred")
  echo "$consul_token" >"$CONSUL_TOKEN_FILE"
  export CONSUL_HTTP_TOKEN="$consul_token"
}

function get_pg_creds() {
  local pg_role=$1
  local vault_pg_creds
  vault_pg_creds=$(vault read "database/static-creds/${pg_role}" -format=json)

  pg_user=$(jq -r '.data.username' <<<"$vault_pg_creds")
  pg_password=$(jq -r '.data.password' <<<"$vault_pg_creds")

  export PGUSER="$pg_user"
  export PGPASSWORD="$pg_password"
}

echo "WARNING: make sure to run this inside the terraform root folder"

# get config env
env="$1"

if [[ -z "$env" ]]; then
  read -rp "Enter env to use [minikube/homelab]: " env
else
  shift # remove env from positional args
fi

case "$env" in
"minikube")
  export VAULT_ADDR="https://vault.minikube.io"
  #export CONSUL_HTTP_ADDR=""
  ;;
"homelab")
  export VAULT_ADDR="https://vault.homelab.eeternalsadness.dev"
  #export CONSUL_HTTP_ADDR=""
  ;;
*)
  echo "Unrecognized input: '${env}'. Input must be 'minikube' or 'homelab'!"
  exit 1
  ;;
esac

#export CONSUL_LEASE_FILE="$(dirname $0)/../envs/${env}/.config/vault_consul_lease_id"
#export CONSUL_TOKEN_FILE="$(dirname $0)/../envs/${env}/.config/consul_token"
export VAULT_TOKEN_FILE="$(dirname $0)/../envs/${env}/.config/vault_token"
