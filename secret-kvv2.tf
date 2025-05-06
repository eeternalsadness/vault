resource "vault_mount" "kvv2" {
  path = var.vault-path-secret-kv-v2
  type = "kv"
  options = {
    version = "2"
  }
  description = "KV version 2 secret engine mount"
}
