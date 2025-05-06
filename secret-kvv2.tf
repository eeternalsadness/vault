locals {
  # map name => yaml content for each kv secret file
  secret-kvv2-map = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-secret-kv), "*.yaml") :
    trimsuffix(file_name, ".yaml") => yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name)))
    if try(yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name))).spec.enableVersioning, false)
  }

  secret-kvv2-import = {
    for k, v in local.secret-kvv2-map :
    k => {
      path = format("%s/%s", vault_mount.kvv2.path, v.metadata.path)
    }
    if try(v.spec.import, false) && try(v.spec.enableVersioning, false)
  }

  # map name => yaml content for each kv secret file
  # IF rotateInterval is set AND (there's no timestamp OR modify timestamp + rotateInterval < current timestamp)
  secret-kvv2-rotation-map = {
    for k, v in local.secret-kvv2-map :
    k => v
    if try(v.spec.enableVersioning, false) && contains(keys(v.spec), "rotateInterval") && timecmp(
      timeadd(
        contains(keys(v.metadata), "timestamp") ? v.metadata.timestamp : "2001-09-11T00:00:00+00:00",
        try(v.spec.rotateInterval, "0s")
      ),
      plantimestamp()
    ) <= 0
  }

  # map of public secrets (don't need to be generated)
  secret-kvv2-public = {
    for k, v in local.secret-kvv2-rotation-map : k => v.spec.public
    if contains(keys(v.spec), "public")
  }

  # map of secret keys that need to be generated
  secret-kvv2-generated-keys = merge([
    for k, v in local.secret-kvv2-rotation-map : {
      for secret in v.spec.generated : "${k}/${secret}" => secret
    }
    if contains(keys(v.spec), "generated")
  ]...)

  # map of secrets that need to be generated with their generated values
  secret-kvv2-generated = {
    for k, v in local.secret-kvv2-rotation-map : k => merge([
      {
        for secret in v.spec.generated :
        secret => data.external.generate-secret-kvv2["${k}/${secret}"].result.secret
      }
    ]...)
    if contains(keys(v.spec), "generated")
  }

  # combined map of public and generated secrets
  secret-kvv2-secrets = {
    for key in keys(local.secret-kvv2-public) : key => merge(local.secret-kvv2-public[key], local.secret-kvv2-generated[key])
  }
}

resource "vault_mount" "kvv2" {
  path = var.vault-path-secret-kv-v2
  type = "kv"
  options = {
    version = "2"
  }
  description = "KV version 2 secret engine mount"
}

resource "vault_kv_secret_backend_v2" "kvv2" {
  mount                = vault_mount.kvv2.path
  max_versions         = var.kvv2-max-versions
  delete_version_after = var.kvv2-delete-version-after-seconds
}

resource "vault_kv_secret_v2" "kvv2" {
  for_each = local.secret-kvv2-map

  mount = vault_mount.kvv2.path
  name  = each.value.metadata.path
  # WARN: delete all versions of secret if the config is deleted
  delete_all_versions = true
  # only update for secrets that need to be rotated, otherwise use current value
  data_json = contains(keys(local.secret-kvv2-rotation-map), each.key) ? jsonencode(local.secret-kvv2-secrets[each.key]) : data.vault_kv_secret_v2.kvv2[each.key].data_json

  # get custom_metadata from config if import is false
  dynamic "custom_metadata" {
    for_each = try(!each.value.spec.import, true) ? ["not_imported"] : []

    content {
      max_versions = try(each.value.spec.maxVersions, null)
      # NOTE: delete the latest version, probably not needed
      delete_version_after = try(each.value.spec.deleteVersionAfterSeconds, null)
    }
  }
}

data "vault_kv_secret_v2" "kvv2" {
  for_each = { for k, v in local.secret-kvv2-map : k => v if !contains(keys(local.secret-kvv2-rotation-map), k) }

  mount = vault_mount.kvv2.path
  name  = each.value.metadata.path
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
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-secret-kv), "*.yaml") :
    trimsuffix(file_name, ".yaml") => file_name
    if try(yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name))).spec.enableVersioning, false)
  }

  provisioner "local-exec" {
    command = "python3 scripts/update-timestamp.py $file_path"
    environment = {
      file_path = format("%s/%s/%s", path.module, var.repo-path-secret-kv, each.value)
    }
  }

  triggers = {
    secret_updated = vault_kv_secret_v2.kvv2[each.key].data_json
  }

  depends_on = [vault_kv_secret_v2.kvv2]
}

import {
  for_each = local.secret-kvv2-import

  id = each.value.path
  to = vault_kv_secret_v2.kvv2[each.key]
}
