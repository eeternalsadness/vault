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
