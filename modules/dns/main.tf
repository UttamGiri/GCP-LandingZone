terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "private_zones" {
  type = list(object({
    name        = string
    dns_name    = string
    description = string
    networks    = list(string)
  }))
  default = []
}

resource "google_dns_managed_zone" "private" {
  for_each = { for z in var.private_zones : z.name => z }

  project     = var.project_id
  name        = each.value.name
  dns_name    = each.value.dns_name
  description = each.value.description

  visibility = "private"

  dynamic "private_visibility_config" {
    for_each = length(each.value.networks) > 0 ? [1] : []
    content {
      dynamic "networks" {
        for_each = each.value.networks
        content {
          network_url = networks.value
        }
      }
    }
  }
}

output "zone_names" {
  value = [for z in google_dns_managed_zone.private : z.name]
}
