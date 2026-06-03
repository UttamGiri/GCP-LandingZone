terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0"
    }
  }

  backend "gcs" {
    bucket = "tf-state-gcp-landing-zone"
    prefix = "stages/0-org-setup"
  }
}

provider "google" {
  user_project_override = true
  billing_project       = var.bootstrap_project_id
}

provider "google-beta" {
  user_project_override = true
  billing_project       = var.bootstrap_project_id
}

variable "bootstrap_project_id" {
  type        = string
  description = "Bootstrap project for API billing (proj-bootstrap)"
}

variable "config_path" {
  type        = string
  description = "Path to configs directory"
  default     = "../../configs"
}

locals {
  global_config   = yamldecode(file("${var.config_path}/global-config.yaml"))
  folders_config  = yamldecode(file("${var.config_path}/folders-config.yaml"))
  projects_config = yamldecode(file("${var.config_path}/projects-config.yaml"))
  iam_config      = yamldecode(file("${var.config_path}/iam-config.yaml"))

  org_id            = local.global_config.organization.id
  billing_account   = local.global_config.billing.account_id
  default_labels    = local.global_config.labels.defaults
  bootstrap_project = var.bootstrap_project_id

  top_level_folders = {
    for f in local.folders_config.folders : f.id => f
    if f.parent == "organization"
  }

  nested_folders = {
    for f in local.folders_config.folders : f.id => f
    if f.parent != "organization"
  }
}

# Bootstrap state bucket
resource "google_storage_bucket" "tf_state" {
  project       = local.bootstrap_project
  name          = local.global_config.terraform.state_bucket
  location      = local.global_config.defaults.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Folders — top level first
module "folders_top" {
  source   = "../../modules/folder"
  for_each = local.top_level_folders

  display_name = each.value.name
  parent       = "organizations/${local.org_id}"
  iam_bindings = lookup(each.value, "iam", {})
}

module "folders_nested" {
  source   = "../../modules/folder"
  for_each = local.nested_folders

  display_name = each.value.name
  parent       = module.folders_top[each.value.parent].name
  iam_bindings = lookup(each.value, "iam", {})

  depends_on = [module.folders_top]
}

locals {
  all_folders = merge(
    { for k, v in module.folders_top : k => v.folder_id },
    { for k, v in module.folders_nested : k => v.folder_id }
  )
}

# Platform projects
module "platform_projects" {
  source   = "../../modules/project"
  for_each = { for p in local.projects_config.projects : p.project_id => p }

  project_id      = each.value.project_id
  name            = each.value.name
  folder_id       = local.all_folders[each.value.folder]
  billing_account = local.billing_account
  labels          = merge(local.default_labels, each.value.labels)
  apis            = each.value.apis
  iam_bindings    = lookup(each.value, "iam_bindings", {})
}

locals {
  org_iam_flat = flatten([
    for g in local.iam_config.groups : [
      for role in g.org_roles : {
        role   = role
        member = "group:${g.email}"
      }
    ]
  ])

  org_iam_bindings = {
    for role in distinct([for b in local.org_iam_flat : b.role]) : role => [
      for b in local.org_iam_flat : b.member if b.role == role
    ]
  }
}

# Custom IAM roles and org-level group bindings
module "iam" {
  source = "../../modules/iam"

  organization_id  = local.org_id
  custom_roles     = local.iam_config.custom_roles
  org_iam_bindings = local.org_iam_bindings
}

# Bootstrap & CI/CD service accounts
module "service_accounts" {
  source   = "../../modules/service-account"
  for_each = { for sa in local.iam_config.service_accounts : sa.account_id => sa }

  project_id    = each.value.project
  account_id    = each.value.account_id
  display_name  = each.value.display_name
  description   = lookup(each.value, "description", "")
  project_roles = each.value.roles

  depends_on = [module.platform_projects]
}

output "organization_id" {
  value = local.org_id
}

output "folder_ids" {
  value = local.all_folders
}

output "project_ids" {
  value = { for k, v in module.platform_projects : k => v.project_id }
}

output "terraform_state_bucket" {
  value = google_storage_bucket.tf_state.name
}

output "service_account_emails" {
  value = { for k, v in module.service_accounts : k => v.email }
}
