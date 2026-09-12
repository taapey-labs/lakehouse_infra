variable "resource_prefix" {
  description = "Prefix for resource tags."
  type        = string
}

variable "sql_warehouse_name" {
  description = "SQL warehouse name. Defaults to the workspace Starter Warehouse."
  type        = string
}

variable "sql_warehouse_cluster_size" {
  description = "SQL warehouse cluster size (for example 2X-Small, X-Small, Small)."
  type        = string
}

variable "sql_warehouse_auto_stop_mins" {
  description = "Minutes of inactivity before the warehouse stops."
  type        = number
}

variable "sql_warehouse_enable_serverless" {
  description = "Whether the starter SQL warehouse uses serverless compute. Must be false when the workspace is not eligible for serverless."
  type        = bool
}
