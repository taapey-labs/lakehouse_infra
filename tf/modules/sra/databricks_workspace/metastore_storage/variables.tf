variable "resource_prefix" {
  type        = string
  description = "Prefix for the metastore external location name."
}

variable "admin_user" {
  type        = string
  description = "Workspace admin granted ALL_PRIVILEGES on the metastore external location and ALL_PRIVILEGES plus MANAGE on the storage credential."
}

variable "metastore_bucket_id" {
  type        = string
  description = "Name of the dedicated metastore S3 bucket."
}

variable "storage_credential_name" {
  type        = string
  description = "Account-level Unity Catalog storage credential name for the metastore bucket."
}
