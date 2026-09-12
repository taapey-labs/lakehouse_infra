output "role_arn" {
  description = "IAM role ARN for the metastore storage credential."
  value       = aws_iam_role.metastore.arn
}

output "storage_credential_name" {
  description = "Unity Catalog storage credential for the metastore bucket."
  value       = databricks_storage_credential.metastore.name
}

output "external_location_name" {
  description = "Unity Catalog external location for the metastore bucket."
  value       = databricks_external_location.metastore.name
}
