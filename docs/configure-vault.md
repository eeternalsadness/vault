# Configure Vault

This guide explains how to configure Vault using YAML and HCL files in the `envs/{env_name}` directory structure.

## Table of Contents

- [Overview](#overview)
- [Configure High-Level Settings with tfvars File](#configure-high-level-settings-with-tfvars-file)
- [Configuration Structure](#configuration-structure)
- [KV v2 Secrets](#kv-v2-secrets)
- [Policies](#policies)
- [Authentication Backends](#authentication-backends)
- [Database Secrets Engine](#database-secrets-engine)
- [Consul Integration](#consul-integration)
- [Best Practices](#best-practices)
- [Next Steps](#next-steps)

## Overview

The Vault self-service approach allows you to define Vault resources using simple YAML and HCL files. Terraform automatically processes these files and creates the corresponding Vault resources. This eliminates the need to write Terraform code for common Vault operations.

## Configure High-Level Settings with tfvars File

The `{env_name}.tfvars` file contains configurations for where configuration files are located in the repository and some high-level settings for secret engines. This should be configured once and only modified when needed.

Key configuration options include:

- Repository paths for policies, secrets, and authentication backends
- Vault mount paths for different secret engines
- Consul and database connection settings
- Secret generation and rotation parameters

## Configuration Structure

All configuration files follow a consistent structure:

```
envs/
├── {env_name}/                    # Environment (dev, prod, staging)
│   ├── secrets/                   # Secret engine configurations
│   │   ├── kv/                    # KV v2 secrets
│   │   ├── database/              # Database connections and roles
│   │   └── consul/                # Consul integration
│   ├── policies/                  # Vault policies (HCL format)
│   └── auth/                      # Authentication backends
│       └── jwt/                   # JWT authentication
│           └── ...                # Various JWT backends (jwt-gitlab, oidc-google, etc.)
```

## KV v2 Secrets

KV v2 secrets are defined in `envs/{env_name}/secrets/kv/` using YAML files.

### Basic Structure

```yaml
metadata:
  path: secret/path              # Secret path (excluding mount path)
  timestamp: '2025-01-27T...'   # Auto-generated timestamp

spec:
  # Configuration options
  import: false                  # Whether to import existing secrets
  rotateInterval: 24h           # Auto-rotation interval (optional)
  
  # Secret content
  public:                        # Fixed key-value pairs
    username: admin
    host: example.com
  
  private:                       # Secret keys (values imported from Vault)
    - password
    - api_key
  
  generated:                     # Auto-generated secret keys
    - session_token
    - encryption_key
```

### Configuration Options

| Field | Type | Description | Required |
|-------|------|-------------|---------|
| `metadata.path` | string | Secret path in Vault | Yes |
| `metadata.timestamp` | string | Last update timestamp (auto-generated) | No |
| `spec.import` | boolean | Import existing secrets | No |
| `spec.rotateInterval` | string | Auto-rotation interval | No |
| `spec.maxVersions` | number | Max versions per secret | No |
| `spec.deleteVersionAfterSeconds` | number | Version retention period | No |

### Secret Types

1. Public Secrets

Configuration values that are not sensitive:

```yaml
spec:
  public:
    username: app_user
    database_url: "postgresql://localhost:5432/myapp"
    max_connections: 100
```

2. Private Secrets

Sensitive values that are either imported from existing Vault secrets OR manually edited in Vault after creation:

```yaml
# Import existing secrets
spec:
  import: true
  private:
    - password
    - api_key
    - ssl_certificate

# OR manually edit secrets (3rd party provided)
spec:
  import: false
  private:
    - api_token          # Generated as stub, manually edited in Vault
    - client_secret      # Generated as stub, manually edited in Vault
    - webhook_url        # Generated as stub, manually edited in Vault
```

3. Generated Secrets

Automatically generated random values:

```yaml
spec:
  generated:
    - password
    - encryption_key
    - jwt_secret
```

### Rotation Configuration

The `rotateInterval` field serves two purposes:

1. **Auto-rotation for generated secrets**: Only generated secrets are automatically rotated when you run Terraform
2. **Rotation tracking for all secrets**: The self-service outputs ALL secrets (regardless of type) that are due for rotation based on `timestamp + rotateInterval < current_time`

```yaml
spec:
  generated:
    - password
  rotateInterval: 4380h  # 6 months
```

**Important Notes:**

- **Generated secrets**: Automatically rotated by Terraform
- **Public/Private secrets**: Not auto-rotated, but tracked for manual rotation
- **All secret types**: Will appear in Terraform output if due for rotation

Common rotation intervals:

- `24h` - Daily
- `168h` - Weekly (7 days)
- `720h` - Monthly (30 days)
- `4380h` - Semi-annually (6 months)
- `8760h` - Annually (1 year)

### Examples

#### Simple Application Secret

```yaml
# envs/dev/secrets/kv/my-app/config.yaml
metadata:
  path: my-app/config
spec:
  public:
    app_name: "My Application"
    environment: "development"
    version: "1.0.0"
  generated:
    - api_key
    - jwt_secret
  rotateInterval: 168h
```

#### Imported Secret

```yaml
# envs/dev/secrets/kv/third-party/api.yaml
metadata:
  path: third-party/api
spec:
  import: true
  private:
    - api_key
    - client_secret
    - webhook_token
```

## Policies

Vault policies are defined in `envs/{env_name}/policies/` using HCL (HashiCorp Configuration Language) files.

### Basic Policy Structure

```hcl
# envs/dev/policies/my-app.hcl
path "kvv2/data/my-app/*" {
  capabilities = ["read"]
}

path "kvv2/metadata/my-app/*" {
  capabilities = ["read"]
}
```

### Common Capabilities

- `read` - Read secret data
- `create` - Create new secrets
- `update` - Update existing secrets
- `delete` - Delete secrets
- `list` - List secret paths

### Policy Examples

See the [policy examples](/examples/policies/) for complete configuration examples.

## Authentication Backends

Authentication backends are configured in `envs/{env_name}/auth/` using YAML files.

### JWT Authentication

JWT authentication backends are configured in `envs/{env_name}/auth/jwt/`.

See the [authentication examples](/examples/auth/) for complete configuration examples:

- [JWT GitLab Backend](/examples/auth/jwt/jwt-gitlab/)
- [Google OIDC Backend](/examples/auth/jwt/oidc-google/)

## Database Secrets Engine

Database connections are configured in `envs/{env_name}/secrets/database/`. Currently, the following are supported:

- MongoDB
- MSSQL
- Redis
- Elasticsearch

### MongoDB Configuration

See the [MongoDB database example](/examples/secrets/database/mongodb-dev/) for complete configuration:

- [MongoDB Connection](/examples/secrets/database/mongodb-dev/mongodb-dev.yaml)
- [Database Roles](/examples/secrets/database/mongodb-dev/roles/)

## Consul Integration

The Consul backend is configured in Terraform (`secret-consul.tf`), while Consul roles are defined in `envs/{env_name}/secrets/consul/` using YAML files.

### Consul Roles

See the [Consul role example](/examples/secrets/consul/) for configuration.

## Best Practices

1. File Organization

- Use descriptive, hierarchical paths for secrets
- Group related secrets in subdirectories
- Keep environment-specific configurations separate

2. Security

- Use `public` only for non-sensitive configuration
- Set appropriate rotation intervals for sensitive secrets
- Limit policy permissions to minimum required access

## Next Steps

- [Examples](/examples/) - Configuration examples
- [Scripts](/scripts/) - Automation scripts
- [GitLab Integration](/docs/gitlab-integration.md) - CI/CD setup
- [Database Configuration](/docs/configure-database-secrets-engine.md) - Database setup
