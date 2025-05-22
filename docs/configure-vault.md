# Configure Vault

- [Configure high-level settings with tfvars file](#configure-high-level-settings-with-tfvars-file)
- [Add or update policies](#add-or-update-policies)
- [Configure Vault JWT/OIDC backends](#configure-vault-jwtoidc-backends)
- [Create a KV secret](#create-a-kv-secret)
  - [Examples](#examples)
- [Configure the database secrets engine](#configure-the-database-secrets-engine)
- [GitLab integration](#gitlab-integration)

You can configure Vault using `yaml` and `hcl` files in `envs/{env_name}`. The comments in the existing configuration files should help you understand what each field does.

## Configure high-level settings with tfvars file

The `envs/{env_name}/.config/terraform.tfvars` file contains configurations for where configuration files are located in the repository and some high-level settings for secret engines. This should be configured once and only modified when needed.

## Add or update policies

Vault policies (`.hcl` files) can be added or updated in `envs/{env_name}/policies`. The name of the file is used as the name for the policy.

## Configure Vault JWT/OIDC backends

See [Configure Vault JWT/OIDC backends](/docs/configure-vault-jwtoidc-backends.md).

## Create a KV secret

KV secrets are defined in `envs/{env_name}/secrets/kv`.

For generated secrets (secrets with the `spec.generated` fields), you can define a rotation interval (`spec.rotateInterval`) to automatically generate new secrets once the interval has passed when you run `terraform plan` or `terraform apply`. A Python script is used to update the timestamp of when the secrets were last updated, and that timestamp is used to determine if the secrets need to be rotated or not.

### Examples

- [Generated secret](/envs/minikube/secrets/kv/examples/kvv2.yaml)
- [Imported secrets](/envs/minikube/secrets/kv/examples/kvv2-import.yaml)

## Configure the database secrets engine

See [Configure Database Secrets Engine](/docs/configure-database-secrets-engine.md).

## GitLab integration

See [GitLab Integration](/docs/gitlab-integration.md).
