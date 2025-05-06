locals {
  # map name => yaml content for each kv secret file
  secret-kv-map = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-secret-kv), "*.yaml") :
    trimsuffix(file_name, ".yaml") => yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name)))
    if try(!yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name))).spec.enableVersioning, true)
  }

  secret-kv-import = {
    for k, v in local.secret-kv-map :
    k => {
      path = format("%s/%s", vault_mount.kv.path, v.metadata.path)
    }
    if try(v.spec.import, false)
  }

  # map name => yaml content for each kv secret file
  # IF rotateInterval is set AND (there's no timestamp OR modify timestamp + rotateInterval < current timestamp)
  secret-kv-rotation-map = {
    for k, v in local.secret-kv-map :
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
  secret-kv-public = {
    for k, v in local.secret-kv-rotation-map : k => v.spec.public if contains(keys(v.spec), "public")
  }

  # map of secret keys that need to be generated
  secret-kv-generated-keys = merge([
    for k, v in local.secret-kv-rotation-map : {
      for secret in v.spec.generated : "${k}/${secret}" => secret
    }
    if contains(keys(v.spec), "generated")
  ]...)

  # map of secrets that need to be generated with their generated values
  secret-kv-generated = {
    for k, v in local.secret-kv-rotation-map : k => merge([
      {
        for secret in v.spec.generated :
        secret => data.external.generate-secret-kv["${k}/${secret}"].result.secret
      }
    ]...)
    if contains(keys(v.spec), "generated")
  }

  # combined map of public and generated secrets
  secret-kv-secrets = {
    for key in keys(local.secret-kv-public) : key => merge(local.secret-kv-public[key], local.secret-kv-generated[key])
  }
}

resource "vault_mount" "kv" {
  path = var.vault-path-secret-kv
  type = "kv"
  options = {
    version = "1"
  }
  description               = "KV version 1 secret engine mount"
  default_lease_ttl_seconds = var.kv-lease-ttl-seconds
  max_lease_ttl_seconds     = var.kv-lease-ttl-seconds
}

resource "vault_kv_secret" "kv" {
  for_each = local.secret-kv-map

  path = format("%s/%s", vault_mount.kv.path, each.value.metadata.path)
  # only update for secrets that need to be rotated, otherwise use current value
  data_json = contains(keys(local.secret-kv-rotation-map), each.key) ? jsonencode(local.secret-kv-secrets[each.key]) : data.vault_kv_secret.kv[each.key].data_json
}

data "vault_kv_secret" "kv" {
  for_each = { for k, v in local.secret-kv-map : k => v if !contains(keys(local.secret-kv-rotation-map), k) }

  path = format("%s/%s", vault_mount.kv.path, each.value.metadata.path)
}

# generate secrets for secrets that need to be rotated
data "external" "generate-secret-kv" {
  for_each = local.secret-kv-generated-keys

  program = ["python3", "scripts/generate-secret.py"]
  query = {
    length  = var.kv-generated-secret-length
    symbols = var.kv-generated-secret-use-symbols
  }
}

# update timestamp in yaml file after a secret is created/updated for rotation purposes
resource "null_resource" "kv_update_timestamp" {
  for_each = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-secret-kv), "*.yaml") :
    trimsuffix(file_name, ".yaml") => file_name
    if try(!yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name))).spec.enableVersioning, true)
  }

  provisioner "local-exec" {
    command = "python3 scripts/update-timestamp.py $file_path"
    environment = {
      file_path = format("%s/%s/%s", path.module, var.repo-path-secret-kv, each.value)
    }
  }

  triggers = {
    secret_updated = vault_kv_secret.kv[each.key].data_json
  }

  depends_on = [vault_kv_secret.kv]
}

import {
  for_each = local.secret-kv-import

  id = each.value.path
  to = vault_kv_secret.kv[each.key]
}
