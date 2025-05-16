# Vault Terraform

- [Setup](#setup)
- [Log in to Vault via the CLI](#log-in-to-vault-via-the-cli)
- [Running Terraform commands](#running-terraform-commands)
- [Configure Vault](#configure-vault)

## Setup

Before running `terraform` or `vault` commands, the following environment variables need to be exported:

```bash
# Vault server address
export VAULT_ADDR="https://vault.example.com"
```

Also, make sure you're in a Python virtual environment with `pyyaml` installed (this is needed for the rotation script).

```bash
pip install pyyaml
```

## Log in to Vault via the CLI

To manage Vault with Terraform, you need to log in to Vault with the `terraform-vault` role from the CLI and export the token that's returned from the login request.

```bash
vault login -method=oidc -path=oidc-google role="terraform-vault"
export VAULT_TOKEN="some-vault-token"
```

To simplify this login process, you can add the following alias to your `.bashrc` (if using `bash`) or `.zshrc` (if using `zsh`) file and source it.

```bash
vault_login() {
  local role="$1"
  local mount_path="${2:-oidc-google}"

  # NOTE: make sure jq is installed
  export VAULT_TOKEN=$(vault login -method=oidc -path="$mount_path" role="$role" -format=json | jq -r .auth.client_token)
}
alias vl='vault_login'
```

You can then log in to any role with the `vl` alias.

```bash
vl terraform-vault
```

## Configure Vault

See [Configure Vault](/docs/configure-vault.md).

## To-dos

- [ ] Implement [lease duration](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v1#ttls) for kv secrets
- [x] Decide whether or not to deprecate kvv1 secrets in favor of kvv2
