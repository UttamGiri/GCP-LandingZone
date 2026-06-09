terraform {
  cloud {
    organization = "vaflt-org"

    workspaces {
      name = "object-storage-dev"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
  }
}
