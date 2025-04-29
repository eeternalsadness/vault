# REPO PATHS

variable "repo-path-policy" {
  type    = string
  default = "config/policies"
}

variable "repo-path-secret-kv" {
  type    = string
  default = "config/secrets/kv"
}

variable "repo-path-auth-jwt" {
  type    = string
  default = "config/auth/jwt"
}

# VAULT PATHS

variable "vault-path-secret-kv" {
  type    = string
  default = "kvv1"
}
