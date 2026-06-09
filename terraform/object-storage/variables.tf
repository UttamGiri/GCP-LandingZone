variable "project_id" {
  description = "Target project for storage bucket."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique GCS bucket name."
  type        = string
}

variable "bucket_location" {
  description = "Bucket location."
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Environment label (dev/prod)."
  type        = string
  default     = "dev"
}
