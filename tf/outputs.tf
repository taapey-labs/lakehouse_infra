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
  description = "Unity Catalog catalog backed by the new S3 bucket and existing instance profile."
  value       = databricks_catalog.additional.name
}

output "additional_catalog_bucket" {
  description = "S3 bucket used as storage_root for the additional catalog."
  value       = aws_s3_bucket.additional_catalog.id
}

output "additional_catalog_instance_profile_role_arn" {
  description = "IAM role ARN behind the existing instance profile (granted S3 access)."
  value       = data.aws_iam_role.catalog_instance_profile.arn
}

output "additional_catalog_uc_trust_external_id" {
  description = "sts:ExternalId to add on the instance profile role trust for Unity Catalog (if not already present)."
  value       = databricks_storage_credential.additional_catalog.aws_iam_role[0].external_id
  sensitive   = true
}
