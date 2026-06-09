terraform {
  cloud {
    organization = "vaflt-org"

    workspaces {
      name = "bootstrap-dev"
    }
  }
}
