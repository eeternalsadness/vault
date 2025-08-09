locals {
  secret-consul-roles = {
    for file_name in fileset("${path.module}/${var.repo-path-secret-consul}", "*.{yaml,yml}") :
    yamldecode(file("${path.module}/${var.repo-path-secret-consul}/${file_name}")).metadata.name
    => yamldecode(file("${path.module}/${var.repo-path-secret-consul}/${file_name}"))
  }
}

resource "vault_consul_secret_backend" "consul" {
  count = length(keys(local.secret-consul-roles)) == 0 ? 0 : 1

  path        = var.vault-path-secret-consul
  description = "Consul secret backend"
  address     = var.consul-address
  scheme      = "https"
  #token       = jsondecode(vault_kv_secret_v2.kvv2[var.consul-bootstrap-token-path].data_json).bootstrap_token
  # NOTE: if Consul hasn't been bootstrapped, set this to true to secure the bootstrap token (the token field is not required)
  bootstrap                 = true
  default_lease_ttl_seconds = var.consul-default-lease-ttl-seconds
  max_lease_ttl_seconds     = var.consul-max-lease-ttl-seconds

  depends_on = [vault_policy.policy]
}

resource "vault_consul_secret_backend_role" "consul" {
  for_each = local.secret-consul-roles

  name            = each.value.metadata.name
  backend         = vault_consul_secret_backend.consul[0].path
  consul_policies = each.value.spec.consulPolicies
  ttl             = each.value.spec.ttlSeconds
  max_ttl         = each.value.spec.ttlSeconds

  depends_on = [vault_policy.policy]
}

