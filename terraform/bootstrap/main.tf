locals {
  github_repository = "${var.github_org}/${var.github_repo}"
  terraform_roles = [
    "roles/serviceusage.serviceUsageAdmin",
    "roles/logging.logWriter",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.workloadIdentityPoolAdmin"
  ]
}

resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com"
  ])

  project            = var.bootstrap_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "terraform_deployer" {
  account_id   = var.terraform_service_account_id
  display_name = "Terraform Deployer (GitHub OIDC)"
  project      = var.bootstrap_project_id

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "terraform_deployer_roles" {
  for_each = toset(local.terraform_roles)

  project = var.bootstrap_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions Pool"
  project                   = var.bootstrap_project_id

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "GitHub OIDC Provider"
  project                            = var.bootstrap_project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${local.github_repository}' && (assertion.ref.startsWith('refs/heads/') || assertion.ref.startsWith('refs/pull/'))"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.terraform_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repository}"
}
