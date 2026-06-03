terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "key_rings" {
  type = list(object({
    name     = string
    location = string
    keys = list(object({
      name            = string
      purpose         = string
      rotation_period = string
    }))
  }))
  default = []
}

resource "google_kms_key_ring" "rings" {
  for_each = { for r in var.key_rings : r.name => r }

  project  = var.project_id
  name     = each.value.name
  location = each.value.location
}

locals {
  keys = flatten([
    for ring in var.key_rings : [
      for key in ring.keys : {
        ring_name       = ring.name
        location        = ring.location
        key_name        = key.name
        purpose         = key.purpose
        rotation_period = key.rotation_period
      }
    ]
  ])
}

resource "google_kms_crypto_key" "keys" {
  for_each = { for k in local.keys : "${k.ring_name}-${k.key_name}" => k }

  name            = each.value.key_name
  key_ring        = google_kms_key_ring.rings[each.value.ring_name].id
  purpose         = each.value.purpose
  rotation_period = each.value.rotation_period

  lifecycle {
    prevent_destroy = true
  }
}

output "key_ids" {
  value = { for k, v in google_kms_crypto_key.keys : k => v.id }
}

output "key_names" {
  value = { for k, v in google_kms_crypto_key.keys : k => v.name }
}
