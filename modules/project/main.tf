terraform {
  required_version = ">= 1.5.0"
}

variable "project_id" {
  type = string
}

variable "name" {
  type = string
}

variable "folder_id" {
  type        = string
  description = "Folder ID (numeric) to create project under"
}

variable "billing_account" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "apis" {
  type    = list(string)
  default = []
}

variable "iam_bindings" {
  type    = map(list(string))
  default = {}
}

variable "auto_create_network" {
  type    = bool
  default = false
}

resource "google_project" "this" {
  project_id          = var.project_id
  name                = var.name
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  labels              = var.labels
  auto_create_network = var.auto_create_network
}

resource "google_project_service" "apis" {
  for_each = toset(var.apis)

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_iam_binding" "bindings" {
  for_each = var.iam_bindings

  project = google_project.this.project_id
  role    = each.key
  members = each.value

  depends_on = [google_project_service.apis]
}

output "project_id" {
  value = google_project.this.project_id
}

output "project_number" {
  value = google_project.this.number
}

output "project_name" {
  value = google_project.this.name
}
