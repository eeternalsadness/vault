locals {
  secret-kv-files = { for file_name in fileset()}
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
  path = format("%s/test", vault_mount.mount_kv.path)
  data_json = jsonencode(
    {
      username = "test"
      password = data.external.generate-secret.result
    }
  )
}
