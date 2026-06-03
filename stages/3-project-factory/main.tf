terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }

  backend "gcs" {
    bucket = "tf-state-gcp-landing-zone"
    prefix = "stages/3-project-factory"
  }
}

provider "google" {}

variable "config_path" {
  type    = string
  default = "../../configs"
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = "tf-state-gcp-landing-zone"
    prefix = "stages/0-org-setup"
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = "tf-state-gcp-landing-zone"
    prefix = "stages/2-networking"
  }
}

locals {
  global_config    = yamldecode(file("${var.config_path}/global-config.yaml"))
  workloads_config = yamldecode(file("${var.config_path}/workloads-config.yaml"))

  billing_account = local.global_config.billing.account_id
  default_labels  = local.global_config.labels.defaults
  folder_ids      = data.terraform_remote_state.org.outputs.folder_ids
  subnet_ids      = data.terraform_remote_state.network.outputs.subnet_ids
}

# Workload projects — Account Factory equivalent
module "workload_projects" {
  source   = "../../modules/project"
  for_each = { for w in local.workloads_config.workloads : w.project_id => w }

  project_id      = each.value.project_id
  name            = each.value.name
  folder_id       = local.folder_ids[each.value.folder]
  billing_account = local.billing_account
  labels          = merge(local.default_labels, each.value.labels)
  apis            = each.value.apis
  iam_bindings    = each.value.iam_bindings
}

# Attach workload projects to Shared VPC
resource "google_compute_shared_vpc_service_project" "workload" {
  for_each = {
    for w in local.workloads_config.workloads : w.project_id => w
    if lookup(w, "shared_vpc", { enabled = false }).enabled
  }

  host_project    = each.value.shared_vpc.host_project
  service_project = each.value.project_id

  depends_on = [module.workload_projects]
}

# Grant subnet usage to service projects
resource "google_compute_subnetwork_iam_member" "subnet_user" {
  for_each = {
    for pair in flatten([
      for w in local.workloads_config.workloads : [
        for subnet in lookup(lookup(w, "shared_vpc", {}), "subnets", []) : {
          key        = "${w.project_id}-${subnet}"
          project_id = w.project_id
          subnet     = subnet
          region     = "us-central1"
        }
      ] if lookup(w, "shared_vpc", { enabled = false }).enabled
    ]) : pair.key => pair
  }

  project    = lookup(yamldecode(file("${var.config_path}/network-config.yaml")).shared_vpc, "host_project", "proj-net-hub")
  region     = each.value.region
  subnetwork = each.value.subnet
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.workload_projects[each.value.project_id].project_number}@cloudservices.gserviceaccount.com"

  depends_on = [google_compute_shared_vpc_service_project.workload]
}

output "workload_project_ids" {
  value = { for k, v in module.workload_projects : k => v.project_id }
}

output "workload_project_numbers" {
  value = { for k, v in module.workload_projects : k => v.project_number }
}
