output "workload_identity_provider" {
  description = "Full resource name for GitHub Action auth configuration."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "terraform_service_account_email" {
  description = "Service account email used by GitHub Actions."
  value       = google_service_account.terraform_deployer.email
}
