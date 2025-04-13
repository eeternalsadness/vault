terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.7.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.4"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }

  required_version = "~> 1.11.0"
}

provider "vault" {
  max_lease_ttl_seconds = 300
}

provider "external" {}
