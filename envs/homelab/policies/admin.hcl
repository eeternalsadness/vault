#####################################
# Policies
#####################################

# create & manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# list policies
path "sys/policies/acl" {
  capabilities = ["list"]
}

#####################################
# Auth
#####################################

# manage auth methods across vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# create, update, delete auth methods
path "sys/auth/*" {
  capabilities = ["create", "update", "delete", "sudo"]
}

# list auth methods
path "sys/auth" {
  capabilities = ["read"]
}

#####################################
# Seal/unseal
#####################################

# allow to seal vault
path "sys/seal"
{
  capabilities = ["update", "sudo"]
}

# allow to unseal vault
path "sys/unseal"
{
  capabilities = ["update", "sudo"]
}

#####################################
# Leases
#####################################

# look up leases
path "sys/leases/lookup/" {
  capabilities = ["list", "sudo"]
}

# look up leases
path "sys/leases/lookup/*" {
  capabilities = ["list", "sudo"]
}

# revoke leases
path "sys/leases/revoke" {
  capabilities = ["update", "sudo"]
}

# revoke leases based on prefix
path "sys/leases/revoke-prefix/*" {
  capabilities = ["update", "sudo"]
}

#####################################
# Mounts
#####################################

# manage secret engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# list secret engines
path "sys/mounts" {
  capabilities = ["read", "list"]
}

# remount
path "sys/remount" {
  capabilities = ["update"]
}

#####################################
# KVV2
#####################################

# kvv2 secrets
path "kvv2/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

#####################################
# Database
#####################################

# database secrets
path "database/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

#####################################
# Others
#####################################

# read only on other paths
path "*" {
  capabilities = ["read", "list"]
}
