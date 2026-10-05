output "cluster_id" {
  description = "ID of the Repos Git Proxy cluster (workspace-conf gitProxyClusterId)."
  value       = databricks_cluster.this.id
}

output "cluster_name" {
  description = "Name of the Repos Git Proxy cluster."
  value       = databricks_cluster.this.cluster_name
}
