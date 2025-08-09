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
# CONSUL
#####################################

# consul secrets
path "consul/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

#####################################
# DATABASE
#####################################

# database secrets
path "database/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
