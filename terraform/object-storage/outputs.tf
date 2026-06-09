output "bucket_name" {
  description = "Created GCS bucket name."
  value       = google_storage_bucket.object_storage.name
}

output "bucket_url" {
  description = "GCS bucket URL."
  value       = "gs://${google_storage_bucket.object_storage.name}"
}
