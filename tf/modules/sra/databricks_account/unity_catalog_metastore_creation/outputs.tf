output "metastore_id" {
  description = "Metastore ID."
  value       = var.metastore_exists ? data.databricks_metastore.this[0].id : databricks_metastore.this[0].id
}

output "metastore_bucket_id" {
  description = "S3 bucket used only for Unity Catalog metastore storage. Empty when serverless."
  value       = var.is_serverless ? null : aws_s3_bucket.metastore[0].id
}

output "metastore_bucket_arn" {
  description = "ARN of the metastore S3 bucket. Empty when serverless."
  value       = var.is_serverless ? null : aws_s3_bucket.metastore[0].arn
}

output "metastore_role_arn" {
  description = "IAM role ARN for the metastore storage credential. Empty when serverless."
  value       = var.is_serverless ? null : aws_iam_role.metastore[0].arn
}

output "storage_credential_name" {
  description = "Account-level Unity Catalog storage credential for the metastore bucket. Empty when serverless."
  value       = var.is_serverless ? null : (local.create_metastore ? databricks_metastore_data_access.metastore[0].name : databricks_storage_credential.metastore[0].name)
}
