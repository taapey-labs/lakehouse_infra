output "workspace_host" {
  value = module.databricks_mws_workspace.workspace_url
}

output "catalog_name" {
  description = "Name of the catalog created for the workspace."
  value       = module.unity_catalog_catalog_creation.catalog_name
}

output "starter_sql_warehouse_id" {
  description = "ID of the starter SQL warehouse."
  value       = module.starter_sql_warehouse.id
}

output "starter_sql_warehouse_name" {
  description = "Name of the starter SQL warehouse."
  value       = module.starter_sql_warehouse.name
}

output "metastore_bucket_id" {
  description = "S3 bucket used only for Unity Catalog metastore storage."
  value       = module.unity_catalog_metastore_creation.metastore_bucket_id
}

output "raw_ingest_bucket_id" {
  description = "S3 bucket for raw data landed from outside Databricks."
  value       = local.is_serverless ? null : module.raw_ingest[0].bucket_id
}

output "raw_ingest_role_arn" {
  description = "IAM role ARN for external writers and Databricks ingest of the raw landing bucket."
  value       = local.is_serverless ? null : module.raw_ingest[0].role_arn
}

output "raw_ingest_storage_credential_name" {
  description = "Unity Catalog storage credential for the raw ingest bucket."
  value       = local.is_serverless ? null : module.raw_ingest[0].storage_credential_name
}

output "raw_ingest_external_location_name" {
  description = "Unity Catalog external location for the raw ingest bucket."
  value       = local.is_serverless ? null : module.raw_ingest[0].external_location_name
}
