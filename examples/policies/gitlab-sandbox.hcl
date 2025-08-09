# read access on secret mount path
path "kvv2" {
  capabilities = ["read"]
}

# read access on test secret
path "kvv2/data/test" {
  capabilities = ["read"]
}
