locals {
  auth-jwt-map = {
    for file_name in fileset("${path.module}/${var.repo-path-auth-jwt}", "*/*.yaml") :
    yamldecode(file("${path.module}/${var.repo-path-auth-jwt}/${file_name}")).metadata.name
    => yamldecode(file("${path.module}/${var.repo-path-auth-jwt}/${file_name}"))
  }

  auth-jwt-role-mappings = {
    for k, v in local.auth-jwt-map : k => merge([
      for file_name in fileset("${path.module}/${var.repo-path-auth-jwt}/${k}/role-mappings", "*.yaml") :
      yamldecode(file("${path.module}/${var.repo-path-auth-jwt}/${k}/role-mappings/${file_name}"))
    ]...)
  }

  auth-jwt-bound-claims = {
    for k, v in local.auth-jwt-role-mappings : k => {
      for role in keys(v) : role => {
        bound_claims = {
          for bound_claim in keys(v[role].boundClaims) :
          bound_claim => join(",", v[role].boundClaims[bound_claim])
        }
      }
    }
  }

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
  oidc_discovery_url = each.value.spec.type == "oidc" ? each.value.spec.oidc.discoveryUrl : null
  oidc_client_id     = each.value.spec.type == "oidc" ? jsondecode(data.vault_kv_secret_v2.jwt[each.key].data_json).client_id : null
  oidc_client_secret = each.value.spec.type == "oidc" ? jsondecode(data.vault_kv_secret_v2.jwt[each.key].data_json).client_secret : null
  bound_issuer       = try(each.value.spec.type == "oidc" ? each.value.spec.oidc.boundIssuer : null, null)
  path               = each.value.spec.mountPath
  type               = each.value.spec.type
  tune {
    listing_visibility = "unauth"
    default_lease_ttl  = try(each.value.spec.defaultLeaseTtl, null)
    max_lease_ttl      = try(each.value.spec.maxLeaseTtl, null)
  }
}

resource "vault_jwt_auth_backend_role" "oidc" {
  for_each = local.auth-oidc-role-map

  backend        = vault_jwt_auth_backend.jwt[each.value.backend_name].path
  role_name      = each.value.role_map.roleName
  token_policies = each.value.role_map.tokenPolicies

  role_type    = "oidc"
  oidc_scopes  = each.value.role_map.scopes
  user_claim   = each.value.role_map.userClaim
  bound_claims = local.auth-jwt-bound-claims[each.value.backend_name][each.value.role_map.roleName].bound_claims

  allowed_redirect_uris = each.value.redirect_urls

  token_explicit_max_ttl = each.value.role_map.tokenTtlSeconds
  token_ttl              = each.value.role_map.tokenTtlSeconds
}

