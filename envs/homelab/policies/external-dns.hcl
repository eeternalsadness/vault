# read access on cloudflare's external-dns API token only
path "kvv2/data/cloudflare/external-dns-api-token" {
  capabilities = ["read"]
}
