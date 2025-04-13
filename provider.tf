terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.7.0"
    }
  }

  required_version = "~> 1.11.0"
}

provider "vault" {
  max_lease_ttl_seconds = 300
}
