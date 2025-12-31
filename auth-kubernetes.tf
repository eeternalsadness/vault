locals {
  auth-kubernetes-map = {
    for file_name in fileset("${path.module}/${var.repo-path-auth-kubernetes}", "*/*.yaml") :
    yamldecode(file("${path.module}/${var.repo-path-auth-kubernetes}/${file_name}")).metadata.name
    => yamldecode(file("${path.module}/${var.repo-path-auth-kubernetes}/${file_name}"))
  }

  auth-kubernetes-roles = merge([
    for backend_name in keys(local.auth-kubernetes-map) : {
      for file_name in fileset("${path.module}/${var.repo-path-auth-kubernetes}/${backend_name}/roles", "*.yaml") :
      format("%s/%s", backend_name, yamldecode(file("${path.module}/${var.repo-path-auth-kubernetes}/${backend_name}/roles/${file_name}")).metadata.name)
      => {
        backend_name = backend_name
        role_config  = yamldecode(file("${path.module}/${var.repo-path-auth-kubernetes}/${backend_name}/roles/${file_name}"))
      }
    }
  ]...)
}

resource "vault_auth_backend" "kubernetes" {
  for_each = local.auth-kubernetes-map

  type        = "kubernetes"
  description = each.value.metadata.description
  path        = each.value.spec.mountPath

  tune {
    listing_visibility = "hidden"
    default_lease_ttl  = try(each.value.spec.defaultLeaseTtl, null)
    max_lease_ttl      = try(each.value.spec.maxLeaseTtl, null)
    token_type         = "default-service"
  }
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  for_each = local.auth-kubernetes-map

  backend                = vault_auth_backend.kubernetes[each.key].path
  kubernetes_host        = each.value.spec.kubernetesHost
  kubernetes_ca_cert     = try(jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.kubernetesCaCertSecretPath].data_json).cert, null)
  token_reviewer_jwt     = try(jsondecode(vault_kv_secret_v2.kvv2[each.value.spec.kubernetesTokenReviewerSecretPath].data_json).token, null)
  issuer                 = try(each.value.spec.issuer, null)
  disable_iss_validation = false

  depends_on = [vault_policy.policy]
}

resource "vault_kubernetes_auth_backend_role" "kubernetes" {
  for_each = local.auth-kubernetes-roles

  backend        = vault_auth_backend.kubernetes[each.value.backend_name].path
  role_name      = each.value.role_config.metadata.name
  token_policies = each.value.role_config.spec.tokenPolicies

  bound_service_account_names      = each.value.role_config.spec.serviceAccountNames
  bound_service_account_namespaces = each.value.role_config.spec.serviceAccountNamespaces

  token_explicit_max_ttl = try(each.value.role_config.spec.tokenTtlSeconds, null)
  token_ttl              = try(each.value.role_config.spec.tokenTtlSeconds, null)

  depends_on = [vault_policy.policy]
}
