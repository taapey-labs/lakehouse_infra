# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/sql_endpoint

data "databricks_sql_warehouses" "all" {}

data "databricks_sql_warehouse" "by_id" {
  for_each = toset(data.databricks_sql_warehouses.all.ids)
  id       = each.value
}

locals {
  existing_starter_id = try(
    [
      for w in data.databricks_sql_warehouse.by_id : w.id
      if w.name == var.sql_warehouse_name
    ][0],
    null
  )
}

# Adopt a warehouse that already exists in the workspace (same name) instead of creating a duplicate.
import {
  for_each = local.existing_starter_id != null ? { (var.sql_warehouse_name) = local.existing_starter_id } : {}
  to       = databricks_sql_endpoint.starter[each.key]
  id       = each.value
}

resource "databricks_sql_endpoint" "starter" {
  for_each = toset([var.sql_warehouse_name])

  name             = each.value
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
  from = databricks_sql_endpoint.starter
  to   = databricks_sql_endpoint.starter["Starter Warehouse"]
}
