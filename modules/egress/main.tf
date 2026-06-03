terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "router_name" {
  type    = string
  default = "egress-router"
}

variable "nat_name" {
  type    = string
  default = "centralized-nat"
}

variable "network" {
  type = string
}

variable "nat_ip_allocate_option" {
  type    = string
  default = "AUTO_ONLY"
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = var.router_name
  region  = var.region
  network = var.network
}

resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = var.nat_name
  router  = google_compute_router.router.name
  region  = var.region

  nat_ip_allocate_option             = var.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

output "router_name" {
  value = google_compute_router.router.name
}

output "nat_name" {
  value = google_compute_router_nat.nat.name
}
