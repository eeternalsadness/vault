# Configure Vault

- [Configure high-level settings with tfvars file](#configure-high-level-settings-with-tfvars-file)
- [Add or update policies](#add-or-update-policies)
- [Add Vault JWT/OIDC roles](#add-vault-jwtoidc-roles)
  - [Examples](#examples)
- [Create a KV secret](#create-a-kv-secret)
- [GitLab integration](#gitlab-integration)

## Add or update policies

Vault policies (`.hcl` files) can be added or updated in `config/policies`. The name of the file is used as the name for the policy.

## Configure JWT/OIDC authentication

To add a JWT/OIDC backend, follow these steps:

1. Add a JWT/OIDC auth backend configuration in `config/auth/jwt/{jwt_backend_name}/{jwt_backend_name}.yaml`.

```yaml
metadata:
  name: oidc-google
  description: "Google OIDC backend"
spec:
  # path to oidc kv secrets in vault (without the mount path)
  secretPath: oidc/google
  # mount path for the auth backend
  mountPath: oidc-google
  # type of jwt auth; can be "jwt" or "oidc"
  type: oidc
  discoveryUrl: "https://accounts.google.com"
  boundIssuer: "https://accounts.google.com"
  redirectUrls:
    - "http://localhost:8250/oidc/callback"
    - "https://vault.example.com/ui/vault/auth/oidc-google/oidc/callback"
  defaultLeaseTtl: "4h"
  maxLeaseTtl: "12h"
  enableOnWebUi: true
```

2. Add a role config in `config/auth/jwt/{jwt_backend_name}/roles/{role_name}.yaml`.

```terraform-vault.yaml
metadata:
  name: terraform-vault
spec:
  # policies for the role
  tokenPolicies:
    - default
    - terraform-vault
  tokenTtlSeconds: 14400 # 4 hours
  # list of OIDC scopes that are returned
  scopes:
    - openid
    - email
  # the OIDC claim to use to identify the user; this will be used as an alias for the entity in vault
  userClaim: "email"
  boundClaims:
    # list of emails that can take on this role
    email:
      - 69bnguyen@gmail.com
```

3. Add a Vault policy (or policies) that should be associated with the role in `config/policies`.

```terraform-vault.hcl
# read-only access to test/* path
path "test/*" {
  capabilities = ["read", "list"]
}
```

### Examples

**OIDC**:

- [Auth backend](/config/auth/jwt/oidc-google/oidc-google.yaml)
- [Role config](/config/auth/jwt/oidc-google/roles/terraform-vault.yaml)

## Create a KV secret

KV secrets are defined in `config/secrets/kv`. Follow the examples in `config/secrets/kv/examples` for more guidance.

For generated secrets (secrets with the `spec.generated` fields), you can define a rotation interval (`spec.rotateInterval`) to automatically generate new secrets once the interval has passed when you run `terraform plan` or `terraform apply`. A Python script is used to update the timestamp of when the secrets were last updated, and that timestamp is used to determine if the secrets need to be rotated or not.

## GitLab integration

See [GitLab Integration](/vault/docs/gitlab-integration.md)
