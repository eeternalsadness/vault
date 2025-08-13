# Vault Terraform

- [Introduction](#introduction)
- [Features](#features)
- [Setup](#setup)
- [Log in to Vault via the CLI](#log-in-to-vault-via-the-cli)
- [Run Terraform commands](#run-terraform-commands)
- [Configure Vault](#configure-vault)
- [To-dos](#to-dos)

## Introduction

This repository provides a GitOps-driven, self-service HashiCorp Vault configuration management system built with Terraform. It enables teams to declaratively manage Vault resources through YAML configuration files, eliminating the need for manual Vault administration while maintaining security best practices.

The system automatically provisions and manages:

- **Secrets Management**: KV v2 secrets with automatic generation, rotation, and lifecycle management
- **Authentication**: JWT/OIDC backends with role-based access control
- **Authorization**: Dynamic policy management from HCL files
- **Database Integration**: Dynamic and static database credentials with automated rotation
- **Service Discovery**: Consul integration for service tokens and policies

All configurations are version-controlled and applied through Terraform, providing audit trails, rollback capabilities, and infrastructure-as-code benefits for your Vault deployment.

## Features

### 🔐 **Secrets Management (KV v2)**

- **Declarative Configuration**: Define secrets in YAML with public and generated values
- **Automatic Generation**: Generate secure passwords and tokens with customizable complexity
- **Time-based Rotation**: Automatic secret rotation based on configurable intervals
- **Import Support**: Import existing secrets from Vault into Terraform state
- **TTL Management**: Per-secret and global TTL configurations
- **Version Control**: Built-in versioning with configurable retention policies

### 🔑 **Authentication & Authorization**

- **JWT/OIDC Integration**: Google OAuth, GitLab CI/CD, and custom OIDC providers
- **Role-based Access**: Fine-grained role definitions with bound claims and policies
- **Dynamic Policies**: HCL policy files automatically deployed and managed
- **Multi-environment**: Separate configurations for different environments

### 🗄️ **Database Secrets Engine**

- **Dynamic Credentials**: On-demand database user creation with automatic cleanup
- **Static Role Rotation**: Periodic rotation of existing database user passwords
- **MongoDB Support**: Native MongoDB connection and role management
- **Credential Templates**: Customizable username patterns and permissions

### 🌐 **Service Integration**

- **Consul Integration**: Automatic Consul token generation and policy binding
- **Multi-backend Support**: Local and Consul Terraform backends

### 🛠️ **Operational Features**

- **GitOps Workflow**: All changes tracked in Git with review processes
- **Automated OIDC Login**: Built-in scripts for seamless authentication

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
vault login -method=oidc -path=auth-backend-mount-path role="role-name"
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

## Run Terraform commands

You can also set up the Terraform scripts to run `terraform plan` and `terraform apply` with built-in Vault OIDC authentication. Update the Vault and Consul (if used as backend) endpoints in [common.sh](/scripts/common.sh) as necessary.

To run `terraform plan` or `terraform apply`, simply run the [plan.sh](/scripts/plan.sh) or [apply.sh](/scripts/apply.sh) script. Make sure you run the scripts from the repo's root folder.

These scripts currently support local and Consul backends.

```bash
./scripts/plan.sh # plan
./scripts/apply.sh # apply
```

## Configure Vault

See [Configure Vault](/docs/configure-vault.md).

## To-dos

- [x] Decide whether or not to deprecate kvv1 secrets in favor of kvv2
- [ ] Implement [lease duration](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v1#ttls) for kv secrets
- [ ] Implement audit logs
- [ ] Implement kubernetes auth
