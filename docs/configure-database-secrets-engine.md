# Database Secrets Engine

## Configure a database connection

To configure a database connection, create the appropriate directories and files in `envs/{env_name}/secrets/database/{connection_name}/{connection_name}.yaml`. Make sure a KV secret has been created for the database's initial root credentials.

```yaml
metadata:
  # name of the database connection
  name: mongodb-dev
spec:
  # type of the database connection (see https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/database_secret_backend_connection for list of valid values)
  type: mongodb
  # the path to the kvv2 secret for the database initial root credentials
  initialRootCredentialsKvPath: "admin/mongodb/development/initial_root_user"
  # list of database statements to execute when rotating the root credentials
  #rootRotationStatements: []
  # mongodb-specific connection configuration
  mongodb:
    # the templated connection URL (see https://developer.hashicorp.com/vault/api-docs/secret/databases/mongodb#sample-payload)
    connectionUrl: "mongodb://{{username}}:{{password}}@localhost:27017/admin"
    # the maximum number of open connections to use
    maxOpenConnections: 500
    # the template to use when generating usernames (see https://developer.hashicorp.com/vault/docs/concepts/username-templating)
    #usernameTemplate: ""
```

## Configure a static role

A static role is mapped to a database user, and its credentials can be rotated automatically by Vault. Before creating a static role, make sure the corresponding user is created in the database that was configured in the connection.

To create a static role, create a `yaml` file in `envs/{env_name}/secrets/database/{connection_name}/roles/{static_role_name}.yaml`.

```yaml
metadata:
  name: static-role
spec:
  # role type; can be "static" or "dynamic"
  type: static
  # name of the database user to associate to the role; omit to generate dynamic roles with unique usernames
  # NOTE: the user MUST EXIST in the database
  username: static-role-user
  # the number of seconds between password rotations
  # WARN: CANNOT be used with rotationSchedule or rotationWindow
  rotationPeriodSeconds: 60 # 1 minute
  # the rotation schedule in cron syntax
  # WARN: CANNOT be used with rotationPeriodSeconds
  #rotationSchedule: "0 0 * * 6" # 12AM on Saturdays
  # the number of seconds in which rotations can occur starting from the rotationSchedule
  # WARN: REQUIRE rotationSchedule; CANNOT be used with rotationPeriodSeconds
  #rotationWindowSeconds: 86400 # 1 day
  # list of database statements (in JSON format) to execute during rotations
  #rotationStatements: []
```

To obtain the credentials for the static role, use the following command.

```bash
vault read database/static-creds/static-role
```

> [!NOTE]
> Users associated with static roles are not automatically deleted when you delete the static roles. The static roles only manage the users' passwords. If you want to delete the associated users, you need to do it manually in the database.

## Configure a dynamic role

A dynamic role allows you to create temporary users in the database with pre-defined permissions.

To create a static role, create a `yaml` file in `envs/{env_name}/secrets/database/{connection_name}/roles/{dynamic_role_name}.yaml`.

```yaml
metadata:
  name: dynamic-role
spec:
  # role type; can be "static" or "dynamic"
  type: dynamic
  # the default number of seconds that this role is valid for
  defaultTtlSeconds: 300 # 5 minutes
  # the maximum number of seconds that this role is valid for
  maxTtlSeconds: 3600 # 1 hour
  # list of creation statements in JSON format
  creationStatements:
    - |
      {
        "db": "example",
        "roles": [
          {
            "role": "read",
            "db": "example"
          }
        ]
      }
```

To obtain the credentials for the static role, use the following command.

```bash
vault read database/creds/dynamic-role
```

> [!NOTE]
> Users associated with dynamic roles are automatically deleted once the TTL expires, even if the associated dynamic roles no longer exist.

## Examples

- [Database connection](/examples/secrets/database/mongodb-dev/mongodb-dev.yaml)
- [Static role](/examples/secrets/database/mongodb-dev/roles/examples/static-role.yaml)
- [Dynamic role](/examples/secrets/database/mongodb-dev/roles/examples/dynamic-role.yaml)
