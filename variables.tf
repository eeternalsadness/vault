# REPO PATHS

variable "repo-path-policy" {
  description = "The path in the repo where policies are configured"
  type        = string
  default     = "config/policies"
}

variable "repo-path-secret-kv" {
  description = "The path in the repo where kv secrets (both v1 and v2) are configured"
  type        = string
  default     = "config/secrets/kv"
}

variable "repo-path-auth-jwt" {
  description = "The path in the repo where jwt auth backends are configured"
  type        = string
  default     = "config/auth/jwt"
}

# VAULT PATHS

variable "vault-path-secret-kv" {
  description = "The path in vault where kv secrets are stored"
  type        = string
  default     = "kvv1"
}

variable "vault-path-secret-kv-v2" {
  description = "The path in vault where kvv2 secrets are stored"
  type        = string
  default     = "kvv2"
}

# KVV2

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
