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
