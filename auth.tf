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

data "vault_kv_secret" "oidc" {
  path = format("%s/%s", vault_mount.mount_kv.path, "oidc/google")
}

resource "vault_jwt_auth_backend" "oidc" {
  description        = "OIDC backend"
  oidc_discovery_url = "https://accounts.google.com"
  oidc_client_id     = jsondecode(data.vault_kv_secret.oidc.data_json).client_id
  oidc_client_secret = jsondecode(data.vault_kv_secret.oidc.data_json).client_secret
  path               = "oidc"
  type               = "oidc"
}

resource "vault_jwt_auth_backend_role" "oidc" {
  backend        = vault_jwt_auth_backend.oidc.path
  role_name      = "terraform-vault"
  token_policies = ["default", "terraform-vault"]

  role_type   = "oidc"
  oidc_scopes = ["openid", "email"]
  user_claim  = "email"
  bound_claims = {
    email = "69bnguyen@gmail.com"
  }

  # FIXME: update once ingress is configured
  allowed_redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "http://localhost:54288/ui/vault/auth/oidc/oidc/callback"
  ]

  # NOTE: limit to 5 min since this token is VERY PERMISSIVE
  token_explicit_max_ttl = 300 # 5 min
  token_ttl              = 300 # 5 min
}
