terraform {
  required_version = ">= 1.5.0"
}

variable "organization_id" {
  type = string
}

variable "policies" {
  type = list(object({
    constraint     = string
    enforce        = bool
    deny_all       = optional(bool, false)
    allowed_values = optional(list(string), [])
    denied_values  = optional(list(string), [])
    scope          = string
    folder_id      = optional(string, "")
    project_id     = optional(string, "")
  }))
}

locals {
  org_policies = {
    for p in var.policies : p.constraint => p if p.scope == "organization"
  }

  folder_policies = {
    for p in var.policies : "${p.folder_id}-${p.constraint}" => p
    if p.scope == "folder" && p.folder_id != ""
  }

  project_policies = {
    for p in var.policies : "${p.project_id}-${p.constraint}" => p
    if p.scope == "project" && p.project_id != ""
  }
}

resource "google_org_policy_policy" "org" {
  for_each = local.org_policies

  name   = "organizations/${var.organization_id}/policies/${each.value.constraint}"
  parent = "organizations/${var.organization_id}"

  spec {
    rules {
      enforce = each.value.enforce

      dynamic "values" {
        for_each = length(each.value.allowed_values) > 0 ? [1] : []
        content {
          allowed_values = each.value.allowed_values
        }
      }

      dynamic "values" {
        for_each = each.value.deny_all ? [1] : []
        content {
          denied_values = ["all"]
        }
      }
    }
  }
}

resource "google_org_policy_policy" "folder" {
  for_each = local.folder_policies

  name   = "folders/${each.value.folder_id}/policies/${each.value.constraint}"
  parent = "folders/${each.value.folder_id}"

  spec {
    rules {
      enforce = each.value.enforce

      dynamic "values" {
        for_each = length(each.value.allowed_values) > 0 ? [1] : []
        content {
          allowed_values = each.value.allowed_values
        }
      }

      dynamic "values" {
        for_each = each.value.deny_all ? [1] : []
        content {
          denied_values = ["all"]
        }
      }
    }
  }
}

resource "google_org_policy_policy" "project" {
  for_each = local.project_policies

  name   = "projects/${each.value.project_id}/policies/${each.value.constraint}"
  parent = "projects/${each.value.project_id}"

  spec {
    rules {
      enforce = each.value.enforce

      dynamic "values" {
        for_each = length(each.value.allowed_values) > 0 ? [1] : []
        content {
          allowed_values = each.value.allowed_values
        }
      }
    }
  }
}
