locals {
  secret-kv-map = {
    for file_name in fileset(var.repo-path-secret-kv, "*.yaml") :
    trimsuffix(file_name, ".yaml") => yamldecode(file(format("%s/%s", var.repo-path-secret-kv, file_name)))
  }

  secret-kv-fixed = {
    for k, v in local.secret-kv-map : k => v.spec.fixed
  }

  secret-kv-generated-keys = merge([
    for k, v in local.secret-kv-map : {
      for secret in v.spec.generated : "${k}/${secret}" => secret
    }
  ]...)

  secret-kv-generated = {
    for k, v in local.secret-kv-map : k => merge([
      for secret in v.spec.generated : { "${secret}" = data.external.generate-secret-kv["${k}/${secret}"].result.secret }
    ]...)
  }

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

  path      = format("%s/%s", vault_mount.mount_kv.path, each.value.metadata.path)
  data_json = jsonencode(local.secret-kv-secrets[each.key])
}

data "external" "generate-secret-kv" {
  for_each = local.secret-kv-generated-keys

  program = ["python3", "scripts/generate-secret.py"]
  query = {
    length  = 16
    symbols = true
  }
}

resource "null_resource" "update_timestamp" {
  for_each = { for file_name in fileset(var.repo-path-secret-kv, "*.yaml") : trimsuffix(file_name, ".yaml") => file_name }

  provisioner "local-exec" {
    command = "python3 scripts/update-timestamp.py $file_path"
    environment = {
      file_path = format("%s/%s", var.repo-path-secret-kv, each.value)
    }
  }

  triggers = {
    secret_updated = vault_kv_secret.secret_kv[each.key].data_json
  }

  depends_on = [vault_kv_secret.secret_kv]
}
