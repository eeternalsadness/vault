# read access on google oidc kvv2 secret
path "kvv2/data/oidc/google" {
  capabilities = ["read"]
}

# read access on grafana contact point secrets
path "kvv2/data/grafana/contact_points/*" {
  capabilities = ["read"]
}

# read access on grafana admin credentials
path "kvv2/data/grafana/users/admin" {
  capabilities = ["read"]
}

# allow creating child tokens
path "auth/token/create" {
  capabilities = ["create", "update"]
}
