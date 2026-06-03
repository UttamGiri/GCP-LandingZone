terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "pool_id" {
  type = string
}

variable "provider_id" {
  type = string
}

variable "issuer_uri" {
  type    = string
  default = "https://token.actions.githubusercontent.com"
}

variable "attribute_mapping" {
  type    = map(string)
  default = {}
}

variable "attribute_condition" {
  type    = string
  default = ""
}

variable "allowed_repositories" {
  type    = list(string)
  default = []
}

resource "google_iam_workload_identity_pool" "pool" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_id
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = var.provider_id

  attribute_mapping = var.attribute_mapping

  attribute_condition = var.attribute_condition != "" ? var.attribute_condition : null

  oidc {
    issuer_uri = var.issuer_uri
  }
}

output "pool_name" {
  value = google_iam_workload_identity_pool.pool.name
}

output "provider_name" {
  value = google_iam_workload_identity_pool_provider.provider.name
}
