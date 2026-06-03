terraform {
  required_version = ">= 1.5.0"
}

variable "organization_id" {
  type = string
}

variable "custom_roles" {
  type = list(object({
    role_id     = string
    title       = string
    description = string
    permissions = list(string)
  }))
  default = []
}

variable "org_iam_bindings" {
  type        = map(list(string))
  description = "Organization-level IAM: role => [members]"
  default     = {}
}

resource "google_organization_iam_custom_role" "roles" {
  for_each = { for r in var.custom_roles : r.role_id => r }

  org_id      = var.organization_id
  role_id     = each.value.role_id
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
}

resource "google_organization_iam_binding" "bindings" {
  for_each = var.org_iam_bindings

  org_id  = var.organization_id
  role    = each.key
  members = each.value
}

output "custom_role_ids" {
  value = { for k, v in google_organization_iam_custom_role.roles : k => v.id }
}
