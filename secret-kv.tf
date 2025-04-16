locals {
  # map name => yaml content for each kv secret file
  secret-kv-map = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-secret-kv), "*.yaml") :
    trimsuffix(file_name, ".yaml") => yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-secret-kv, file_name)))
  }

  # map name => yaml content for each kv secret file
  # IF there's no timestamp OR modify timestamp + rotation interval < current timestamp
  secret-kv-rotation-map = {
    for k, v in local.secret-kv-map : k => v
    if try(v.metadata.timestamp, null) == null || timecmp(timeadd(v.metadata.timestamp, v.spec.interval), plantimestamp()) <= 0
  }

  # map of fixed secrets (don't need to be generated)
  secret-kv-fixed = {
    for k, v in local.secret-kv-rotation-map : k => v.spec.fixed
  }

  # map of secret keys that need to be generated
  secret-kv-generated-keys = merge([
    for k, v in local.secret-kv-rotation-map : {
      for secret in v.spec.generated : "${k}/${secret}" => secret
    }
  ]...)

  # map of secrets that need to be generated with their generated values
  secret-kv-generated = {
    for k, v in local.secret-kv-rotation-map : k => merge([
      for secret in v.spec.generated : { "${secret}" = data.external.generate-secret-kv["${k}/${secret}"].result.secret }
    ]...)
  }

  # combined map of fixed and generated secrets
  secret-kv-secrets = {
    for key in keys(local.secret-kv-fixed) : key => merge(local.secret-kv-fixed[key], local.secret-kv-generated[key])
  }
}

resource "vault_mount" "mount_kv" {
  path = var.vault-path-secret-kv
  type = "kv"
  options = {
    version = "1"
  }
  description = "KV version 1 secret engine mount"
}

resource "vault_kv_secret" "secret_kv" {
  for_each = local.secret-kv-map

  path = format("%s/%s", vault_mount.mount_kv.path, each.value.metadata.path)
  # only update for secrets that need to be rotated, otherwise use current value
  data_json = contains(keys(local.secret-kv-rotation-map), each.key) ? jsonencode(local.secret-kv-secrets[each.key]) : data.vault_kv_secret.secret_kv_data[each.key].data_json
}

# FIXME: this is bad as vault secrets get stored in state & can be displayed in output
data "vault_kv_secret" "secret_kv_data" {
  for_each = { for k, v in local.secret-kv-map : k => v if !contains(keys(local.secret-kv-rotation-map), k) }

  path = format("%s/%s", vault_mount.mount_kv.path, each.value.metadata.path)
}

# generate secrets for secrets that need to be rotated
data "external" "generate-secret-kv" {
  for_each = local.secret-kv-generated-keys

  program = ["python3", "scripts/generate-secret.py"]
  query = {
    length  = 16
    symbols = true
  }
}

# update timestamp in yaml file after a secret is created/updated for rotation purposes
resource "null_resource" "update_timestamp" {
  for_each = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-secret-kv), "*.yaml") :
    trimsuffix(file_name, ".yaml") => file_name
  }

  provisioner "local-exec" {
    command = "python3 scripts/update-timestamp.py $file_path"
    environment = {
      file_path = format("%s/%s/%s", path.module, var.repo-path-secret-kv, each.value)
    }
  }

  triggers = {
    secret_updated = vault_kv_secret.secret_kv[each.key].data_json
  }

  depends_on = [vault_kv_secret.secret_kv]
}
