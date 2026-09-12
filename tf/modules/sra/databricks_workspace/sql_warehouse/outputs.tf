output "id" {
  description = "SQL warehouse ID."
  value       = databricks_sql_endpoint.starter.id
}

output "name" {
  description = "SQL warehouse name."
  value       = databricks_sql_endpoint.starter.name
}
