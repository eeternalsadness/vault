locals {
  auth-jwt-map = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-auth-jwt), "*.yaml") :
    yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-auth-jwt, file_name))).metadata.name
    => yamldecode(file(format("%s/%s/%s", path.module, var.repo-path-auth-jwt, file_name)))
  }

  auth-jwt-oidc-role-mappings = merge([
    for k, v in local.auth-jwt-map : {
      for role in v.spec.oidc.roleMappings :
      format("%s/%s", k, role.roleName) => {
        backend_name  = v.metadata.name
        redirect_urls = v.spec.oidc.redirectUrls
        role_map      = role
      }
    }
    if v.spec.type == "oidc"
  ]...)
}

data "vault_kv_secret" "jwt" {
  for_each = local.auth-jwt-map

  path = format("%s/%s", vault_mount.mount_kv.path, each.value.spec.secretPath)
}

resource "vault_jwt_auth_backend" "jwt" {
  for_each = local.auth-jwt-map

  description        = each.value.metadata.description
  oidc_discovery_url = each.value.spec.oidc.discoveryUrl
  oidc_client_id     = each.value.spec.type == "oidc" ? jsondecode(data.vault_kv_secret.jwt[each.key].data_json).client_id : null
  oidc_client_secret = each.value.spec.type == "oidc" ? jsondecode(data.vault_kv_secret.jwt[each.key].data_json).client_secret : null
  path               = each.value.spec.mountPath
  type               = each.value.spec.type
}

resource "vault_jwt_auth_backend_role" "oidc" {
  for_each = local.auth-jwt-oidc-role-mappings

  backend        = vault_jwt_auth_backend.jwt[each.value.backend_name].path
  role_name      = each.value.role_map.roleName
  token_policies = each.value.role_map.tokenPolicies

  role_type    = "oidc"
  oidc_scopes  = each.value.role_map.scopes
  user_claim   = each.value.role_map.userClaim
  bound_claims = each.value.role_map.boundClaims

  allowed_redirect_uris = each.value.redirect_urls

  token_explicit_max_ttl = each.value.role_map.tokenTtlSeconds
  token_ttl              = each.value.role_map.tokenTtlSeconds
}

