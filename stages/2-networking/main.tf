terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  backend "gcs" {
    bucket = "tf-state-gcp-landing-zone"
    prefix = "stages/2-networking"
  }
}

provider "google" {}

variable "config_path" {
  type    = string
  default = "../../configs"
}

locals {
  network_config = yamldecode(file("${var.config_path}/network-config.yaml"))
  global_config  = yamldecode(file("${var.config_path}/global-config.yaml"))

  shared_vpc = local.network_config.shared_vpc
  subnets = [
    for s in local.shared_vpc.subnets : merge(s, {
      flow_logs_enabled = lookup(s, "flow_logs", { enabled = true }).enabled
      secondary_ranges  = lookup(s, "secondary_ranges", [])
      purpose           = lookup(s, "purpose", "")
      role              = lookup(s, "role", "")
    })
  ]
}

# Shared VPC host + subnets
module "shared_vpc" {
  source = "../../modules/shared-vpc"

  project_id       = local.shared_vpc.host_project
  network_name     = local.shared_vpc.network.name
  routing_mode     = local.shared_vpc.network.routing_mode
  subnets          = local.subnets
  service_projects = local.shared_vpc.service_projects
}

# Centralized egress NAT
module "egress" {
  source = "../../modules/egress"

  project_id  = local.network_config.egress.project
  region      = local.network_config.egress.region
  network     = module.shared_vpc.network_self_link
  router_name = local.network_config.egress.cloud_nat.router
  nat_name    = local.network_config.egress.cloud_nat.name
}

# Private DNS
module "dns" {
  source = "../../modules/dns"

  project_id = local.network_config.dns.project
  private_zones = [
    for z in local.network_config.dns.private_zones : {
      name        = z.name
      dns_name    = z.dns_name
      description = z.description
      networks    = [module.shared_vpc.network_self_link]
    }
  ]
}

# Hierarchical firewall policy
resource "google_compute_firewall" "default_deny_ingress" {
  project = local.shared_vpc.host_project
  name    = "deny-all-ingress-default"
  network = module.shared_vpc.network_name

  priority  = 65534
  direction = "INGRESS"

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  project = local.shared_vpc.host_project
  name    = "allow-internal-rfc1918"
  network = module.shared_vpc.network_name

  priority  = 1000
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "allow_iap" {
  project = local.shared_vpc.host_project
  name    = "allow-iap-ssh-rdp"
  network = module.shared_vpc.network_name

  priority  = 2000
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = ["35.235.240.0/20"]
}

output "network_name" {
  value = module.shared_vpc.network_name
}

output "network_self_link" {
  value = module.shared_vpc.network_self_link
}

output "subnet_ids" {
  value = module.shared_vpc.subnet_ids
}
