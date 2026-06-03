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
    prefix = "stages/4-cicd"
  }
}

provider "google" {}

variable "config_path" {
  type    = string
  default = "../../configs"
}

variable "github_org" {
  type        = string
  description = "GitHub organization for WIF"
  default     = "myorg"
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = "tf-state-gcp-landing-zone"
    prefix = "stages/0-org-setup"
  }
}

locals {
  iam_config = yamldecode(file("${var.config_path}/iam-config.yaml"))
  wif_config = local.iam_config.workload_identity
  cicd_sa    = [for sa in local.iam_config.service_accounts : sa if sa.account_id == "sa-terraform-cicd"][0]
}

# Workload Identity Federation for GitHub Actions / Cloud Build
module "workload_identity" {
  source = "../../modules/workload-identity"

  project_id          = local.wif_config.project
  pool_id             = local.wif_config.pool_id
  provider_id         = local.wif_config.provider_id
  attribute_mapping   = local.wif_config.attribute_mapping
  attribute_condition = local.wif_config.attribute_condition
}

# Allow GitHub repo to impersonate CI/CD service account
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = "projects/${local.wif_config.project}/serviceAccounts/sa-terraform-cicd@${local.wif_config.project}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${module.workload_identity.pool_name}/attribute.repository/${var.github_org}/gcp-landing-zone"
}

# Artifact Registry for Terraform modules and container images
resource "google_artifact_registry_repository" "terraform" {
  project       = "proj-artifact-registry"
  location      = "us-central1"
  repository_id = "terraform-modules"
  format        = "DOCKER"
  description   = "Landing zone Terraform and container artifacts"
}

# Cloud Build trigger for stage deployments
resource "google_cloudbuild_trigger" "landing_zone_plan" {
  project     = "proj-cicd-shared"
  name        = "landing-zone-terraform-plan"
  description = "Run terraform plan on PR"

  github {
    owner = var.github_org
    name  = "gcp-landing-zone"
    pull_request {
      branch = "^(main|develop)$"
    }
  }

  filename = "cloudbuild/cloudbuild-plan.yaml"
}

resource "google_cloudbuild_trigger" "landing_zone_apply" {
  project     = "proj-cicd-shared"
  name        = "landing-zone-terraform-apply"
  description = "Run terraform apply on merge to main"

  github {
    owner = var.github_org
    name  = "gcp-landing-zone"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild/cloudbuild-apply.yaml"
}

output "workload_identity_pool" {
  value = module.workload_identity.pool_name
}

output "artifact_registry_url" {
  value = "${google_artifact_registry_repository.terraform.location}-docker.pkg.dev/proj-artifact-registry/${google_artifact_registry_repository.terraform.repository_id}"
}
