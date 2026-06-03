terraform {
  required_version = ">= 1.5.0"
}

variable "display_name" {
  type        = string
  description = "Folder display name"
}

variable "parent" {
  type        = string
  description = "Parent resource: organizations/{org_id} or folders/{folder_id}"
}

variable "iam_bindings" {
  type        = map(list(string))
  description = "IAM bindings: role => [members]"
  default     = {}
}

resource "google_folder" "this" {
  display_name = var.display_name
  parent       = var.parent
}

resource "google_folder_iam_binding" "bindings" {
  for_each = var.iam_bindings

  folder  = google_folder.this.name
  role    = each.key
  members = each.value
}

output "id" {
  value = google_folder.this.id
}

output "name" {
  value = google_folder.this.name
}

output "folder_id" {
  value = google_folder.this.folder_id
}
