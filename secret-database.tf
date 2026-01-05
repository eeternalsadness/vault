locals {
  database_secrets_path = "${path.module}/${var.repo-path-secret-database}"

  secret_database_map = {
    for file_name in fileset(local.database_secrets_path, "*/*.{yaml,yml}") :
    yamldecode(file("${local.database_secrets_path}/${file_name}")).metadata.name
    => yamldecode(file("${local.database_secrets_path}/${file_name}"))
    if can(yamldecode(file("${local.database_secrets_path}/${file_name}")))
  }

  secret_database_roles = merge([
    for connection in keys(local.secret_database_map) : {
      for file_name in fileset("${local.database_secrets_path}/${connection}/roles", "**/*.{yaml,yml}") :
      format("%s/%s", connection, yamldecode(file("${local.database_secrets_path}/${connection}/roles/${file_name}")).metadata.name)
      => {
        connection  = connection
        role_config = yamldecode(file("${local.database_secrets_path}/${connection}/roles/${file_name}"))
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
    ignore_changes = [mongodb, mssql, redis, elasticsearch, postgresql]
  }

  depends_on = [vault_policy.policy]
}

resource "vault_database_secret_backend_connection" "database" {
  for_each = local.secret_database_map

  backend                  = vault_database_secrets_mount.database.path
  name                     = each.value.metadata.name
  allowed_roles            = [for role in local.secret_database_roles : role.role_config.metadata.name if role.connection == each.value.metadata.name]
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

  dynamic "mssql" {
    for_each = each.value.spec.type == "mssql" ? ["mssql"] : []

    content {
      connection_url       = each.value.spec.mssql.connectionUrl
      username             = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).username
      password             = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).password
      max_open_connections = try(each.value.spec.mssql.maxOpenConnections, null)
      max_idle_connections = try(each.value.spec.mssql.maxIdleConnections, null)
      username_template    = try(each.value.spec.mssql.usernameTemplate, null)
    }
  }

  dynamic "postgresql" {
    for_each = each.value.spec.type == "postgresql" ? ["postgresql"] : []

    content {
      connection_url          = each.value.spec.postgresql.connectionUrl
      username                = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).username
      password                = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).password
      max_open_connections    = try(each.value.spec.postgresql.maxOpenConnections, null)
      max_idle_connections    = try(each.value.spec.postgresql.maxIdleConnections, null)
      username_template       = try(each.value.spec.postgresql.usernameTemplate, null)
      password_authentication = "scram-sha-256"
    }
  }

  dynamic "redis" {
    for_each = each.value.spec.type == "redis" ? ["redis"] : []

    content {
      host         = each.value.spec.redis.host
      port         = each.value.spec.redis.port
      username     = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).username
      password     = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).password
      tls          = try(each.value.spec.redis.tls, null)
      insecure_tls = try(each.value.spec.redis.insecureTls, null)
    }
  }

  dynamic "elasticsearch" {
    for_each = each.value.spec.type == "elasticsearch" ? ["elasticsearch"] : []

    content {
      url               = each.value.spec.elasticsearch.url
      username          = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).username
      password          = jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.initialRootCredentialsKvPath].data_json).password
      tls_server_name   = try(each.value.spec.elasticsearch.tlsServerName)
      insecure          = try(each.value.spec.elasticsearch.insecure)
      username_template = try(each.value.spec.elasticsearch.usernameTemplate)
    }
  }

  depends_on = [vault_policy.policy]
}

resource "vault_database_secret_backend_static_role" "database" {
  for_each = { for k, v in local.secret_database_roles : k => v if v.role_config.spec.type == "static" }

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
  for_each = { for k, v in local.secret_database_roles : k => v if v.role_config.spec.type == "dynamic" }

  backend             = vault_database_secrets_mount.database.path
  name                = each.value.role_config.metadata.name
  db_name             = vault_database_secret_backend_connection.database[each.value.connection].name
  creation_statements = each.value.role_config.spec.creationStatements
  default_ttl         = each.value.role_config.spec.defaultTtlSeconds
  max_ttl             = each.value.role_config.spec.maxTtlSeconds

  depends_on = [vault_policy.policy]
}
