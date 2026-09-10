output "workspace_host" {
  description = "URL of the deployed Databricks workspace."
  value       = module.databricks_sra.workspace_host
}

output "catalog_name" {
  description = "Name of the Unity Catalog catalog created for the workspace."
  value       = module.databricks_sra.catalog_name
}

output "additional_catalog_name" {
  description = "Unity Catalog catalog created alongside the additional S3 bucket (metastore default storage; no credential or external location)."
  value       = databricks_catalog.additional.name
}

output "additional_catalog_bucket" {
  description = "S3 bucket provisioned for later use with the additional catalog."
  value       = aws_s3_bucket.additional_catalog.id
}
