output "bucket_id" {
  description = "Raw ingest S3 bucket name."
  value       = aws_s3_bucket.raw_ingest.id
}

output "role_arn" {
  description = "IAM role ARN for external writers and Databricks ingest."
  value       = aws_iam_role.raw_ingest.arn
}

output "storage_credential_name" {
  description = "Unity Catalog storage credential for the raw ingest bucket."
  value       = databricks_storage_credential.raw_ingest.name
}

output "external_location_name" {
  description = "Unity Catalog external location for the raw ingest bucket."
  value       = databricks_external_location.raw_ingest.name
}
