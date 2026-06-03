terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "network_name" {
  type    = string
  default = "hub-vpc"
}

variable "routing_mode" {
  type    = string
  default = "REGIONAL"
}

variable "subnets" {
  type = list(object({
    name                     = string
    region                   = string
    ip_cidr_range            = string
    private_ip_google_access = optional(bool, true)
    purpose                  = optional(string, "")
    role                     = optional(string, "")
    flow_logs_enabled        = optional(bool, true)
    secondary_ranges = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })), [])
  }))
  default = []
}

variable "service_projects" {
  type    = list(string)
  default = []
}

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "subnets" {
  for_each = { for s in var.subnets : s.name => s }

  project       = var.project_id
  name          = each.value.name
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = each.value.private_ip_google_access
  purpose                  = each.value.purpose != "" ? each.value.purpose : null
  role                     = each.value.role != "" ? each.value.role : null

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  dynamic "log_config" {
    for_each = each.value.flow_logs_enabled ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = var.project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  for_each = toset(var.service_projects)

  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = each.value
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnet_ids" {
  value = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}
