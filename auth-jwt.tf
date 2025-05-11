locals {
  auth-jwt-map = {
    for file_name in fileset("${path.module}/${var.repo-path-auth-jwt}", "*/*.yaml") :
    yamldecode(file("${path.module}/${var.repo-path-auth-jwt}/${file_name}")).metadata.name
    => yamldecode(file("${path.module}/${var.repo-path-auth-jwt}/${file_name}"))
  }

  #auth-jwt-role-mappings = merge([
  #  for file_path in fileset("${path.module}/${var.repo-path-auth-jwt-role-mappings}", "*/*.yaml") : try(merge([
  #    for k, v in yamldecode(file("${path.module}/${var.repo-path-auth-jwt-role-mappings}/${file_path}")) : {
  #      "${basename(dirname(file_path))}" = merge({ folder = basename(dirname(file_path)) }, v)
  #    }
  #  ]...), {})
  #]...)

  auth-jwt-role-mappings = merge([
    for k, v in local.auth-jwt-map : {k => merge([
      for file_name in fileset("${path.module}/${var.repo-path-auth-jwt}/${k}/role-mappings", "*.yaml") : merge([
        yamldecode("${path.module}/${var.repo-path-auth-jwt}/${k}/role-mappings/${file_name}")
      ]...)
    ]...)}
  ]...)

  auth-oidc-role-map = merge([
    for k, v in local.auth-jwt-map : {
      for role in v.spec.oidc.roles :
      format("%s/%s", k, role.roleName) => {
        backend_name  = v.metadata.name
        redirect_urls = v.spec.oidc.redirectUrls
        role_map      = role
      }
    }
    if v.spec.type == "oidc"
  ]...)
}

data "vault_kv_secret_v2" "jwt" {
  for_each = local.auth-jwt-map

  mount = vault_mount.kvv2.path
  name  = each.value.spec.secretPath
}

resource "vault_jwt_auth_backend" "jwt" {
  for_each = local.auth-jwt-map

  description        = each.value.metadata.description
  oidc_discovery_url = each.value.spec.oidc.discoveryUrl
  oidc_client_id     = each.value.spec.type == "oidc" ? jsondecode(data.vault_kv_secret_v2.jwt[each.key].data_json).client_id : null
  oidc_client_secret = each.value.spec.type == "oidc" ? jsondecode(data.vault_kv_secret_v2.jwt[each.key].data_json).client_secret : null
  path               = each.value.spec.mountPath
  type               = each.value.spec.type
}

resource "vault_jwt_auth_backend_role" "oidc" {
  for_each = local.auth-oidc-role-map

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

