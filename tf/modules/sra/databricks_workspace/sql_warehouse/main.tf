# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/sql_endpoint

resource "databricks_sql_endpoint" "starter" {
  name                      = var.sql_warehouse_name
  cluster_size              = var.sql_warehouse_cluster_size
  min_num_clusters          = 1
  max_num_clusters          = 1
  auto_stop_mins            = var.sql_warehouse_auto_stop_mins
  enable_serverless_compute = true
  warehouse_type            = "PRO"

  tags {
    custom_tags {
      key   = "SRA"
      value = var.resource_prefix
    }
  }
}
