variable "bootstrap_project_id" {
  description = "Project ID hosting WIF, SA, and Terraform state bucket."
  type        = string
}

variable "organization_id" {
  description = "GCP organization ID (numeric string)."
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID to associate with projects later."
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user owning repo."
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name allowed to deploy."
  type        = string
}

variable "github_branch" {
  description = "Git ref allowed to deploy (for example refs/heads/main)."
  type        = string
  default     = "refs/heads/main"
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Provider ID."
  type        = string
  default     = "github-provider"
}

variable "terraform_service_account_id" {
  description = "Service account ID (without domain)."
  type        = string
  default     = "tf-deployer"
}
