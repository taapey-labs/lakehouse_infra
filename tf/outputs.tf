output "workspace_host" {
  description = "URL of the deployed Databricks workspace."
  value       = module.databricks_sra.workspace_host
}

output "catalog_name" {
  description = "Name of the Unity Catalog catalog created for the workspace."
  value       = module.databricks_sra.catalog_name
}
