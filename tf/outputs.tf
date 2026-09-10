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
