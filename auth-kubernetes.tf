resource "vault_auth_backend" "auth_backend" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "auth_backend_config_kubernetes" {
  backend         = vault_auth_backend.auth_backend.path
  kubernetes_host = "https://127.0.0.1:53801"
}

resource "vault_kubernetes_auth_backend_role" "auth_backend_role_kubernetes" {
  backend                          = vault_auth_backend.auth_backend.path
  role_name                        = "test"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = ["test"]
  token_max_ttl                    = 300 # 5 min
}
