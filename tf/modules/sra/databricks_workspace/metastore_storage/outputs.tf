output "external_location_name" {
  description = "Unity Catalog external location for the metastore bucket."
  value       = databricks_external_location.metastore.name
}
