output "id" {
  description = "SQL warehouse ID."
  value       = databricks_sql_endpoint.starter[var.sql_warehouse_name].id
}

output "name" {
  description = "SQL warehouse name."
  value       = databricks_sql_endpoint.starter[var.sql_warehouse_name].name
}
