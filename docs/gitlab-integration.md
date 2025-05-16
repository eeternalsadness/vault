# GitLab Integration

- [Vault setup](#vault-setup)
  - [Policy](#policy)
  - [JWT auth backend](#jwt-auth-backend)
  - [JWT auth role](#jwt-auth-role)
- [GitLab setup](#gitlab-setup)
  - [Example](#example)
- [References](#references)

## Vault setup

### Policy

You need to create a Vault policy for your JWT role. This policy needs access to the secret's mount path and the actual secret's path.

```hcl
# read access on secret mount path
path "kvv2" {
  capabilities = ["read"]
}

# read access on test secret
path "kvv2/data/test" {
  capabilities = ["read"]
}
```

### JWT auth backend

The JWT auth backend needs to have the GitLab's server URL as the discovery URL and the bound issuer.

```yaml
metadata:
  name: jwt-gitlab
  description: "GitLab JWT backend"
spec:
  # mount path for the auth backend
  mountPath: jwt-gitlab
  # type of jwt auth; can be "jwt" or "oidc"
  type: jwt
  discoveryUrl: "https://gitlab.com"
  boundIssuer: "https://gitlab.com"
  defaultLeaseTtl: "1h"
  maxLeaseTtl: "2h"
  enableOnWebUi: false
```

### JWT auth role

It's required that the JWT auth role has the correct bound audiences and bound claims. The bound audiences should match the `aud` field in the JWT. Make sure the project ID and `ref` are correct to prevent 403 unauthorized errors.

```yaml
gitlab-sandbox:
  # policies for the role
  tokenPolicies:
    - default
    - gitlab-sandbox
  # the claim to use to identify the user; this will be used as an alias for the entity in vault
  userClaim: "project_id"
  boundClaims:
    iss:
      - https://gitlab.com
      - gitlab.com
    project_id:
      - 1234
    ref:
      - main
    ref_type:
      - branch
  boundAudiences:
    - https://gitlab.com
```

## GitLab setup

GitLab can generate JWTs using the [`id_tokens`](https://docs.gitlab.com/ci/yaml/#id_tokens) keyword. The `aud` field is a list of audiences that need to be matched with the bound audiences configured in the Vault's JWT auth role.

For GitLab Community Edition, you need to log in manually using `vault write` on the auth path ([reference](https://developer.hashicorp.com/well-architected-framework/security/security-cicd-vault#gitlab)).

```bash
export VAULT_TOKEN="$(vault write -field=token auth/$VAULT_JWT_AUTH_PATH/login role=$VAULT_JWT_ROLE jwt=$VAULT_AUTH_TOKEN)"
```

It's also a good idea to revoke the token after it's used with `vault token revoke -self`.

### Example

```.gitlab-ci.yml
stages:
  - readsecret

variables:
  VAULT_SERVER_URL: https://vault.example.com

read_secret:
  stage: readsecret
  id_tokens:
    VAULT_AUTH_TOKEN:
      aud: https://gitlab.com
  image: hashicorp/vault:latest
  variables:
    VAULT_JWT_ROLE: gitlab-sandbox
    VAULT_JWT_AUTH_PATH: jwt-gitlab
  script:
    - export VAULT_ADDR=$VAULT_SERVER_URL
    - export VAULT_TOKEN="$(vault write -field=token auth/$VAULT_JWT_AUTH_PATH/login role=$VAULT_JWT_ROLE jwt=$VAULT_AUTH_TOKEN)"
    - export PASSWORD="$(vault kv get -mount=kvv2 -field=test test)"
    - echo $PASSWORD
    - vault token revoke -self
```

## References

- [https://developer.hashicorp.com/well-architected-framework/security/security-cicd-vault#use-a-best-practice-approach](https://developer.hashicorp.com/well-architected-framework/security/security-cicd-vault#use-a-best-practice-approach)
- [https://github.com/GuyBarros/terraform_vault_gitlab_auth/blob/main/README.md](https://github.com/GuyBarros/terraform_vault_gitlab_auth/blob/main/README.md)
- [https://docs.gitlab.com/ci/secrets/hashicorp_vault/](https://docs.gitlab.com/ci/secrets/hashicorp_vault/)
