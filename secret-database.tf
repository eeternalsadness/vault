locals {
  secret-database-map = try({
    for file_name in fileset("${path.module}/${var.repo-path-secret-database}", "*/*.yaml") :
    yamldecode(file("${path.module}/${var.repo-path-secret-database}/${file_name}")).metadata.name
    => yamldecode(file("${path.module}/${var.repo-path-secret-database}/${file_name}"))
  }, {})

  secret-database-roles = merge([
    for connection in keys(local.secret-database-map) : {
      for file_name in fileset("${path.module}/${var.repo-path-secret-database}/${connection}/roles", "*.yaml") :
      format("%s/%s", connection, yamldecode(file("${path.module}/${var.repo-path-secret-database}/${connection}/roles/${file_name}")).metadata.name)
      => {
        connection  = connection
        role_config = yamldecode(file("${path.module}/${var.repo-path-secret-database}/${connection}/roles/${file_name}"))
      }
    }
  ]...)
}

resource "vault_database_secrets_mount" "database" {
  path                      = var.vault-path-secret-database
  description               = "Database secret engine mount"
  seal_wrap                 = true
  default_lease_ttl_seconds = var.database-default-lease-ttl-seconds
  max_lease_ttl_seconds     = var.database-max-lease-ttl-seconds

  lifecycle {
    ignore_changes = [mongodb]
  }

  depends_on = [vault_policy.policy]
}

#data "vault_kv_secret_v2" "database" {
#  for_each = local.secret-database-map
#
#  mount = vault_mount.kvv2.path
#  name  = each.value.spec.initialRootCredentialsKvPath
#}

resource "vault_database_secret_backend_connection" "database" {
  for_each = local.secret-database-map

  backend                  = vault_database_secrets_mount.database.path
  name                     = each.value.metadata.name
  allowed_roles            = [for role in local.secret-database-roles : role.role_config.metadata.name if role.connection == each.value.metadata.name]
  root_rotation_statements = try(each.value.spec.rootRotationStatements, null)
  verify_connection        = true

  dynamic "mongodb" {
    for_each = each.value.spec.type == "mongodb" ? ["mongodb"] : []

    content {
      connection_url       = each.value.spec.mongodb.connectionUrl
      username             = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).username
      password             = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).password
      max_open_connections = each.value.spec.mongodb.maxOpenConnections
      username_template    = try(each.value.spec.mongodb.usernameTemplate, null)
    }
  }

  depends_on = [vault_policy.policy]
}

resource "vault_database_secret_backend_static_role" "database" {
  for_each = { for k, v in local.secret-database-roles : k => v if v.role_config.spec.type == "static" }

  backend  = vault_database_secrets_mount.database.path
  name     = each.value.role_config.metadata.name
  db_name  = vault_database_secret_backend_connection.database[each.value.connection].name
  username = each.value.role_config.spec.username

  rotation_period     = try(each.value.role_config.spec.rotationPeriodSeconds, null)
  rotation_schedule   = try(each.value.role_config.spec.rotationSchedule, null)
  rotation_window     = try(each.value.role_config.spec.rotationWindowSeconds, null)
  rotation_statements = try(each.value.role_config.spec.rotationStatements, null)

  depends_on = [vault_policy.policy]
}

resource "vault_database_secret_backend_role" "database" {
  for_each = { for k, v in local.secret-database-roles : k => v if v.role_config.spec.type == "dynamic" }

  backend             = vault_database_secrets_mount.database.path
  name                = each.value.role_config.metadata.name
  db_name             = vault_database_secret_backend_connection.database[each.value.connection].name
  creation_statements = each.value.role_config.spec.creationStatements
  default_ttl         = each.value.role_config.spec.defaultTtlSeconds
  max_ttl             = each.value.role_config.spec.maxTtlSeconds

  depends_on = [vault_policy.policy]
}
