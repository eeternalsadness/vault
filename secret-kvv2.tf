locals {
  # map name => yaml content for each kv secret file
  secret-kvv2-map = {
    for file_name in fileset("${path.module}/${var.repo-path-secret-kv}", "*.yaml") :
    yamldecode(file("${path.module}/${var.repo-path-secret-kv}/${file_name}")).metadata.path
    => yamldecode(file("${path.module}/${var.repo-path-secret-kv}/${file_name}"))
  }

  secret-kvv2-import = merge([
    for file_name in fileset("${path.module}/${var.repo-path-secret-kv}/imports", "*.yaml") : {
      for secret_path in yamldecode(file("${path.module}/${var.repo-path-secret-kv}/imports/${file_name}")) :
      secret_path => {
        path            = secret_path
        path_with_mount = format("%s/data/%s", vault_mount.kvv2.path, secret_path)
      }
    }
  ]...)

  # combination of defined and imported secrets' paths (key = path)
  secret-kvv2-paths = concat(keys(local.secret-kvv2-map), keys(local.secret-kvv2-import))

  # secrets with timestamps (defined + imported)
  # this determines which secrets need to be fetched through data
  secret-kvv2-data = concat([for k, v in local.secret-kvv2-map : k if contains(keys(v.metadata), "timestamp")], keys(local.secret-kvv2-import))

  # map name => yaml content for each kv secret file
  # IF rotateInterval is set AND (there's no timestamp OR modify timestamp + rotateInterval < current timestamp)
  secret-kvv2-rotation-map = {
    for k, v in local.secret-kvv2-map :
    k => v
    if contains(keys(v.spec), "rotateInterval") && timecmp(
      timeadd(
        contains(keys(v.metadata), "timestamp") ? v.metadata.timestamp : "2001-09-11T00:00:00+00:00",
        try(v.spec.rotateInterval, "0s")
      ),
      plantimestamp()
    ) <= 0
  }

  # map of public secrets (don't need to be generated)
  secret-kvv2-public = {
    for k, v in local.secret-kvv2-map : k => v.spec.public
    if contains(keys(v.spec), "public")
  }

  # map of secret keys that need to be generated
  # IF secrets with generated field AND (there's no timestamp OR secret is set for rotation)
  secret-kvv2-generated-keys = merge([
    for k, v in local.secret-kvv2-map : {
      for secret in v.spec.generated : "${k}/${secret}" => secret
    }
    if contains(keys(v.spec), "generated") && (contains(keys(local.secret-kvv2-rotation-map), k) || !contains(keys(v.metadata), "timestamp"))
  ]...)

  # map of secrets that need to be generated with their generated values
  secret-kvv2-generated = {
    for k, v in local.secret-kvv2-map : k => merge([
      {
        for secret in v.spec.generated :
        secret => data.external.generate-secret-kvv2["${k}/${secret}"].result.secret
      }
    ]...)
    if contains(keys(v.spec), "generated") && (contains(keys(local.secret-kvv2-rotation-map), k) || !contains(keys(v.metadata), "timestamp"))
  }

  # combined map of public and generated secrets
  secret-kvv2-secrets = {
    for key in keys(local.secret-kvv2-map) : key => merge(try(local.secret-kvv2-public[key], {}), try(local.secret-kvv2-generated[key], {}))
    if contains(keys(local.secret-kvv2-public), key) || contains(keys(local.secret-kvv2-generated), key)
  }
}

resource "vault_mount" "kvv2" {
  path = var.vault-path-secret-kv-v2
  type = "kv"
  options = {
    version = "2"
  }
  description               = "KV version 2 secret engine mount"
  default_lease_ttl_seconds = var.kvv2-lease-ttl-seconds
  max_lease_ttl_seconds     = var.kvv2-lease-ttl-seconds

  depends_on = [vault_policy.policy]
}

resource "vault_kv_secret_backend_v2" "kvv2" {
  mount                = vault_mount.kvv2.path
  max_versions         = var.kvv2-max-versions
  delete_version_after = var.kvv2-delete-version-after-seconds

  depends_on = [vault_policy.policy]
}

resource "vault_kv_secret_v2" "kvv2" {
  for_each = toset(local.secret-kvv2-paths)

  mount = vault_mount.kvv2.path
  name  = contains(keys(local.secret-kvv2-map), each.value) ? local.secret-kvv2-map[each.value].metadata.path : local.secret-kvv2-import[each.value].path
  # WARN: delete all versions of secret if the config is deleted
  delete_all_versions = true
  # only update for secrets that need to be rotated, otherwise use current value
  data_json = contains(local.secret-kvv2-data, each.key) ? data.vault_kv_secret_v2.kvv2[each.value].data_json : jsonencode(local.secret-kvv2-secrets[each.value])

  # get custom_metadata from config if not imported
  dynamic "custom_metadata" {
    for_each = contains(keys(local.secret-kvv2-map), each.value) ? ["not_imported"] : []

    content {
      max_versions = try(local.secret-kvv2-map[each.value].spec.maxVersions, null)
      # NOTE: delete the latest version, probably not needed
      delete_version_after = try(local.secret-kvv2-map[each.value].spec.deleteVersionAfterSeconds, null)
    }
  }

  depends_on = [vault_policy.policy]
}

data "vault_kv_secret_v2" "kvv2" {
  for_each = toset(local.secret-kvv2-data)

  mount = vault_mount.kvv2.path
  name  = contains(keys(local.secret-kvv2-map), each.key) ? local.secret-kvv2-map[each.key].metadata.path : local.secret-kvv2-import[each.key].path
}

# generate secrets for secrets that need to be rotated
data "external" "generate-secret-kvv2" {
  for_each = local.secret-kvv2-generated-keys

  program = ["python3", "scripts/generate-secret.py"]
  query = {
    length  = var.kv-generated-secret-length
    symbols = var.kv-generated-secret-use-symbols
  }
}

# update timestamp in yaml file after a secret is created/updated for rotation purposes
resource "null_resource" "kvv2_update_timestamp" {
  for_each = {
    for file_name in fileset("${path.module}/${var.repo-path-secret-kv}", "*.yaml") :
    file_name => yamldecode(file("${path.module}/${var.repo-path-secret-kv}/${file_name}"))
  }

  provisioner "local-exec" {
    command = "python3 scripts/update-timestamp.py $file_path $timestamp"
    environment = {
      file_path = format("%s/%s/%s", path.module, var.repo-path-secret-kv, each.key)
      timestamp = vault_kv_secret_v2.kvv2[each.value.metadata.path].metadata.created_time
    }
  }

  triggers = {
    secret_updated = vault_kv_secret_v2.kvv2[each.value.metadata.path].data_json
  }

  depends_on = [vault_kv_secret_v2.kvv2]
}

import {
  for_each = local.secret-kvv2-import

  id = each.value.path_with_mount
  to = vault_kv_secret_v2.kvv2[each.key]
}
