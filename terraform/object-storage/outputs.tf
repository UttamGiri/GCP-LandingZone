output "bucket_name" {
  description = "Created GCS bucket name."
  value       = google_storage_bucket.object_storage.name
}

output "bucket_url" {
  description = "GCS bucket URL."
  value       = "gs://${google_storage_bucket.object_storage.name}"
}

output "extra_bucket_name" {
  description = "Created extra GCS bucket name."
  value       = google_storage_bucket.object_storage_extra.name
}

output "extra_bucket_url" {
  description = "Extra GCS bucket URL."
  value       = "gs://${google_storage_bucket.object_storage_extra.name}"
}

output "archive_bucket_name" {
  description = "Created archive GCS bucket name."
  value       = google_storage_bucket.object_storage_archive.name
}

output "archive_bucket_url" {
  description = "Archive GCS bucket URL."
  value       = "gs://${google_storage_bucket.object_storage_archive.name}"
}
