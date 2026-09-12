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
