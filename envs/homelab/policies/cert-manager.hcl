# read access on cloudflare's cert-manager API token only
path "kvv2/data/cloudflare/cert-manager-api-token" {
  capabilities = ["read"]
}
