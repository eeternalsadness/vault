# read access on kvv2 mount path
path "kvv2" {
  capabilities = ["read"]
}

# read access on google oidc kvv2 secret
path "kvv2/data/oidc/google" {
  capabilities = ["read"]
}

# read access on grafana kvv2 secret
path "kvv2/data/grafana" {
  capabilities = ["read"]
}

# allow creating child tokens
path "auth/token/create" {
  capabilities = ["create", "update"]
}
