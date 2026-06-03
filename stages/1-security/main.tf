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
    prefix = "stages/1-security"
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

locals {
  global_config   = yamldecode(file("${var.config_path}/global-config.yaml"))
  security_config = yamldecode(file("${var.config_path}/security-config.yaml"))
  org_id          = local.global_config.organization.id
  region          = local.global_config.defaults.region

  folder_ids = data.terraform_remote_state.org.outputs.folder_ids

  org_policies = [
    for p in local.security_config.org_policies : merge(p, {
      folder_id = lookup(p, "folder", "") != "" ? local.folder_ids[p.folder] : ""
    })
  ]
}

# Organization policies (SCP equivalent)
module "org_policies" {
  source = "../../modules/org-policies"

  organization_id = local.org_id
  policies        = local.org_policies
}

# KMS key rings
module "kms" {
  source = "../../modules/kms"

  project_id = local.security_config.kms.key_rings[0].project
  key_rings  = local.security_config.kms.key_rings

  depends_on = [module.org_policies]
}

# Log archive buckets
module "logging" {
  source = "../../modules/logging"

  project_id      = "proj-log-archive"
  organization_id = local.org_id

  buckets = [
    {
      name                        = "org-audit-logs"
      location                    = local.region
      uniform_bucket_level_access = true
      retention_days              = local.global_config.logging.retention_days
      kms_key_name                = module.kms.key_ids["org-keyring-log-encryption"]
    },
    {
      name                        = "vpc-flow-logs"
      location                    = local.region
      uniform_bucket_level_access = true
      retention_days              = 90
    }
  ]

  bigquery_datasets = [
    {
      dataset_id = "audit_logs"
      location   = local.region
    }
  ]

  log_sinks = local.security_config.log_sinks

  depends_on = [module.kms]
}

# Grant log sink writer access to buckets
resource "google_storage_bucket_iam_member" "audit_log_writer" {
  bucket = "org-audit-logs"
  role   = "roles/storage.objectCreator"
  member = module.logging.sink_writer_identities["org-audit-logs"]
}

resource "google_storage_bucket_iam_member" "flow_log_writer" {
  bucket = "vpc-flow-logs"
  role   = "roles/storage.objectCreator"
  member = module.logging.sink_writer_identities["org-vpc-flow-logs"]
}

resource "google_bigquery_dataset_iam_member" "audit_bq_writer" {
  dataset_id = "audit_logs"
  project    = "proj-audit-logs"
  role       = "roles/bigquery.dataEditor"
  member     = module.logging.sink_writer_identities["org-admin-activity"]
}

# Enable SCC APIs
resource "google_project_service" "scc" {
  for_each = toset(local.security_config.scc.services)

  project            = local.security_config.scc.project
  service            = each.value
  disable_on_destroy = false
}

output "kms_key_ids" {
  value = module.kms.key_ids
}

output "log_sink_identities" {
  value = module.logging.sink_writer_identities
}
