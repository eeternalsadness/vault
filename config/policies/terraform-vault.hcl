# FIXME: is there a way to tune this down? it probably needs all the perms to manage vault
path "*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
