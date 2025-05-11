# Vault Terraform

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

  # NOTE: make sure jq is installed
  export VAULT_TOKEN=$(vault login -method=oidc -path=oidc-google role="$role" -format=json | jq -r .auth.client_token)
}
alias vl='vault_login'
```

You can then log in to any role with the `vl` alias.

```bash
vl terraform-vault
```

## Configure Vault

You can configure Vault using `yaml` and `hcl` files in `config`. The comments in the existing configuration files should help you understand what each field does.

### Configure high-level settings with tfvars file

The `.tfvars` file contains configurations for where configuration files are located in the repository and some high-level settings for secret engines. This should be configured once and only modified when needed.

### Add or update policies

Vault policies (`.hcl` files) can be added or updated in `config/policies`. The name of the file is used as the name for the policy.

### Add Vault OIDC roles

To add an OIDC role, follow these steps:

1. Add a Vault policy (or policies) that should be associated with the role in `config/policies`.

```test.hcl
# read-only access to test/* path
path "test/*" {
  capabilities = ["read", "list"]
}
```

2. Add a list item for the desired role in `config/auth/jwt/oidc-google.yaml` under `spec.roles`.

```yaml
metadata:
  name: oidc-google
  description: "Google OIDC backend"
spec:
  # path to oidc kv secrets in vault (without the mount path)
  secretPath: oidc/google
  # mount path for the auth backend
  mountPath: oidc
  # type of jwt auth; can be "jwt" or "oidc"
  type: oidc
  oidc:
    discoveryUrl: "https://accounts.google.com"
    redirectUrls:
      - "http://localhost:8250/oidc/callback"
      - "https://vault-dev.kvfnb.vip/ui/vault/auth/oidc/oidc/callback"
    roles:
      # add the 'test' role
      - roleName: test
        tokenPolicies:
          - default # the default policy (should be included in most roles)
          - test # the test policy that was just defined
        # list of OIDC scopes that are returned
        scopes:
          - openid
          - email
        # how long the token is valid for; max 1 work day (~12h)
        tokenTtlSeconds: 14400 # 4 hours
```

3. Update the role mapping for the role in `config/auth/jwt/role-mappings`. This should be a list of claims that can take on the role. You can modify the list later as necessary.

```yaml
test:
  boundClaims:
    emails:
      - test@example.com
      - admin@example.com
```

### Create a KV secret

KV secrets are defined in `config/secrets/kv`. Follow the examples in `config/secrets/kv/examples` for more guidance.

For generated secrets (secrets with the `spec.generated` fields), you can define a rotation interval (`spec.rotateInterval`) to automatically generate new secrets once the interval has passed when you run `terraform plan` or `terraform apply`. A Python script is used to update the timestamp of when the secrets were last updated, and that timestamp is used to determine if the secrets need to be rotated or not.

## To-dos

- [ ] Implement [lease duration](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v1#ttls) for kv secrets
- [ ] Decide whether or not to deprecate kvv1 secrets in favor of kvv2
