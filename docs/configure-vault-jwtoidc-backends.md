# Configure Vault JWT/OIDC Backends

To configure a JWT/OIDC backend, follow these steps:

1. Configure the backend in `envs/{env_name}/auth/jwt/{jwt_backend_name}/{jwt_backend_name}.yaml`.

```yaml
metadata:
  name: oidc-google
  description: "Google OIDC backend"
spec:
spec:
  # OIDC only: path to oidc kv secrets in vault (without the mount path)
  secretPath: oidc/google
  # mount path for the auth backend
  mountPath: oidc-google
  # type of jwt auth; can be "jwt" or "oidc"
  type: oidc
  discoveryUrl: "https://accounts.google.com"
  boundIssuer: "https://accounts.google.com"
  redirectUrls:
    - "http://localhost:8250/oidc/callback" # CLI
    - "https://vault.example.com/ui/vault/auth/oidc-google/oidc/callback" # web
  defaultLeaseTtl: "4h"
  maxLeaseTtl: "12h"
  # whether or not to show the auth method on the web UI
  enableOnWebUi: true
```

2. Configure the role(s) for the backend by creating `yaml` files in `envs/{env_name}/auth/jwt/{jwt_backend_name}/roles`.

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

3. Add a Vault policy (or policies) that should be associated with the role(s) in `envs/{env_name}/policies`.

```hcl
# read-only access to test/* path
path "test/*" {
  capabilities = ["read", "list"]
}
```

## Examples

**OIDC**:

- [Auth backend](/envs/minikube/auth/jwt/oidc-google/oidc-google.yaml)
- [Role config](/envs/minikube/auth/jwt/oidc-google/roles/terraform-vault.yaml)
