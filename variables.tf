#variable "vault-address" {
#  description = "The URL of the vault server (hostname + port)"
#  type        = string
#  default     = "https://vault.minikube.io"
#}

variable "consul-address" {
  description = "The URL of the Consul server (hostname + port)"
  type        = string
  default     = "https://consul.minikube.io"
}

variable "vault-max-lease-ttl-seconds" {
  description = "Duration of intermediate tokens that Terraform gets from Vault"
  type        = number
  default     = 600 # 10 minutes
}

###################################
# REPO PATHS
###################################

variable "repo-path-policy" {
  description = "The path in the repo where policies are configured"
  type        = string
  default     = "envs/minikube/policies"
}

variable "repo-path-secret-kv" {
  description = "The path in the repo where kv secrets are configured"
  type        = string
  default     = "envs/minikube/secrets/kv"
}

variable "repo-path-secret-database" {
  description = "The path in the repo where database connections and roles are configured"
  type        = string
  default     = "envs/minikube/secrets/database"
}

variable "repo-path-secret-consul" {
  description = "The path in the repo where Consul secrets backend roles are configured"
  type        = string
  default     = "envs/minikube/secrets/consul"
}

variable "repo-path-auth-jwt" {
  description = "The path in the repo where jwt auth backends are configured"
  type        = string
  default     = "envs/minikube/auth/jwt"
}

###################################
# VAULT PATHS
###################################

variable "vault-path-secret-kv-v2" {
  description = "The path in vault where kvv2 secrets are stored"
  type        = string
  default     = "kvv2"
}

variable "vault-path-secret-database" {
  description = "The path in vault where the database secret backend is mounted"
  type        = string
  default     = "database"
}

variable "vault-path-secret-consul" {
  description = "The path in vault where the Consul secret backend is mounted"
  type        = string
  default     = "consul"
}

###################################
# KV SECRETS
###################################

variable "kv-generated-secret-length" {
  description = "The length of generated kv secrets"
  type        = number
  default     = 16
}

variable "kv-generated-secret-use-symbols" {
  description = "Whether or not to include symbols in kv secrets (change the list of allowed symbols in scripts/generate-secret.py)"
  type        = bool
  default     = true
}

variable "kvv2-lease-ttl-seconds" {
  description = "Number of seconds that a kvv2 secret is valid for, after which it needs to be fetched again"
  type        = number
  default     = 300 # 5 minutes
}

variable "kvv2-max-versions" {
  description = "Max number of versions a kvv2 secret can have"
  type        = number
  default     = 5
}

variable "kvv2-delete-version-after-seconds" {
  description = "Number of seconds a kvv2 secret version should be retained for before getting deleted"
  type        = number
  default     = null
}

###################################
# DATABASE SECRETS
###################################

variable "database-default-lease-ttl-seconds" {
  description = "The default number of seconds that a generated database secret is valid for"
  type        = number
  default     = 300 # 4 hours
}

variable "database-max-lease-ttl-seconds" {
  description = "The max number of seconds that a generated database secret can be valid for"
  type        = number
  default     = 3600 # 1 hour
}

###################################
# CONSUL SECRETS
###################################

variable "consul-default-lease-ttl-seconds" {
  description = "The default number of seconds that a generated Consul token is valid for"
  type        = number
  default     = 14400 # 4 hours
}

variable "consul-max-lease-ttl-seconds" {
  description = "The max number of seconds that a generated Consul token can be valid for"
  type        = number
  default     = 43200 # 12 hours
}

variable "consul-bootstrap-token-path" {
  description = "The kvv2 secret path where Consul's bootstrap token is stored"
  type        = string
  default     = "consul/bootstrap-token"
}
