terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "organization_id" {
  type = string
}

variable "log_sinks" {
  type = list(object({
    name             = string
    destination      = string
    filter           = string
    include_children = bool
  }))
  default = []
}

variable "buckets" {
  type = list(object({
    name                        = string
    location                    = string
    uniform_bucket_level_access = bool
    retention_days              = optional(number, 365)
    kms_key_name                = optional(string, "")
  }))
  default = []
}

variable "bigquery_datasets" {
  type = list(object({
    dataset_id = string
    location   = string
  }))
  default = []
}

resource "google_storage_bucket" "log_buckets" {
  for_each = { for b in var.buckets : b.name => b }

  project                     = var.project_id
  name                        = each.value.name
  location                    = each.value.location
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  force_destroy               = false

  dynamic "encryption" {
    for_each = each.value.kms_key_name != "" ? [1] : []
    content {
      default_kms_key_name = each.value.kms_key_name
    }
  }

  retention_policy {
    is_locked        = false
    retention_period = each.value.retention_days * 86400
  }

  versioning {
    enabled = true
  }
}

resource "google_bigquery_dataset" "log_datasets" {
  for_each = { for d in var.bigquery_datasets : d.dataset_id => d }

  project    = var.project_id
  dataset_id = each.value.dataset_id
  location   = each.value.location
}

resource "google_logging_organization_sink" "sinks" {
  for_each = { for s in var.log_sinks : s.name => s }

  name             = each.value.name
  org_id           = var.organization_id
  destination      = each.value.destination
  filter           = each.value.filter
  include_children = each.value.include_children
}

output "sink_writer_identities" {
  value = {
    for k, v in google_logging_organization_sink.sinks : k => v.writer_identity
  }
}

output "bucket_names" {
  value = [for b in google_storage_bucket.log_buckets : b.name]
}
