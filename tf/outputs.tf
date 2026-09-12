output "workspace_host" {
  description = "URL of the deployed Databricks workspace."
  value       = module.aws_databricks_sra.workspace_host
}

output "catalog_name" {
  description = "Name of the Unity Catalog catalog created for the workspace."
  value       = module.aws_databricks_sra.catalog_name
}

output "metastore_bucket" {
  description = "S3 bucket used only for Unity Catalog metastore storage."
  value       = module.aws_databricks_sra.metastore_bucket_id
}

output "starter_sql_warehouse_id" {
  description = "ID of the starter SQL warehouse."
  value       = module.aws_databricks_sra.starter_sql_warehouse_id
}

output "raw_ingest_bucket" {
  description = "S3 bucket for raw data landed from outside Databricks."
  value       = module.aws_databricks_sra.raw_ingest_bucket_id
}

output "raw_ingest_role_arn" {
  description = "IAM role ARN for external writers and Databricks ingest of the raw landing bucket."
  value       = module.aws_databricks_sra.raw_ingest_role_arn
}

output "raw_ingest_storage_credential" {
  description = "Unity Catalog storage credential for the raw ingest bucket."
  value       = module.aws_databricks_sra.raw_ingest_storage_credential_name
}

output "raw_ingest_external_location" {
  description = "Unity Catalog external location name for the raw ingest bucket."
  value       = module.aws_databricks_sra.raw_ingest_external_location_name
}
