resource "google_storage_bucket" "object_storage" {
  name                        = var.bucket_name
  location                    = var.bucket_location
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    stack       = "object-storage"
  }
}

resource "google_storage_bucket" "object_storage_extra" {
  name                        = "${var.bucket_name}-extra"
  location                    = var.bucket_location
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    stack       = "object-storage"
    bucket_type = "extra"
  }
}
