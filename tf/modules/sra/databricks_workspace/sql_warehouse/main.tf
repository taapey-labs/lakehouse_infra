# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/sql_endpoint

# Look up by name (known at plan). Do not for_each over databricks_sql_warehouses.ids;
# that set is computed and Terraform rejects it as "known only after apply".
data "databricks_sql_warehouse" "existing" {
  name = var.sql_warehouse_name
}

import {
  to = databricks_sql_endpoint.starter
  id = data.databricks_sql_warehouse.existing.id
}

resource "databricks_sql_endpoint" "starter" {
  name             = var.sql_warehouse_name
  cluster_size     = var.sql_warehouse_cluster_size
  min_num_clusters = 1
  max_num_clusters = 1
  auto_stop_mins   = var.sql_warehouse_auto_stop_mins
  warehouse_type   = "PRO"

  tags {
    custom_tags {
      key   = "SRA"
      value = var.resource_prefix
    }
  }
}

moved {
  from = databricks_sql_endpoint.starter["Starter Warehouse"]
  to   = databricks_sql_endpoint.starter
}
