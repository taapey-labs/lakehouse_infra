output "workspace_host" {
  description = "URL of the deployed Databricks workspace."
  value       = module.databricks_sra.workspace_host
}

output "catalog_name" {
  description = "Name of the Unity Catalog catalog created for the workspace."
  value       = module.databricks_sra.catalog_name
}

output "unity_catalog_network_policy_id" {
  description = "Network policy rebound onto the workspace so Unity Catalog can call it (KCUC4)."
  value       = databricks_account_network_policy.unity_catalog_access.network_policy_id
}

output "additional_catalog_name" {
  description = "Unity Catalog catalog backed by the new S3 bucket and existing storage credential."
  value       = databricks_catalog.additional.name
}

output "additional_catalog_bucket" {
  description = "S3 bucket used as storage_root for the additional catalog."
  value       = aws_s3_bucket.additional_catalog.id
}

output "additional_catalog_storage_credential" {
  description = "Existing Unity Catalog storage credential used for the additional catalog bucket."
  value       = local.existing_storage_credential_name
}

output "additional_catalog_credential_role_arn" {
  description = "IAM role ARN from the existing storage credential (granted S3 access to the new bucket)."
  value       = data.aws_iam_role.existing_credential.arn
}
