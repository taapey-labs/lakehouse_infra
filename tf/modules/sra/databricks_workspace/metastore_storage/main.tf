# Workspace Unity Catalog external location and grants for the dedicated
# metastore S3 bucket. The bucket, IAM role, and storage credential are created
# on the account (unity_catalog_metastore_creation).

resource "databricks_external_location" "metastore" {
  name               = "${var.resource_prefix}-metastore-external-location"
  url                = "s3://${var.metastore_bucket_id}/base"
  credential_name    = var.storage_credential_name
  comment            = "Dedicated Unity Catalog metastore storage bucket"
  isolation_mode     = "ISOLATION_MODE_OPEN"
  skip_validation    = true
  enable_file_events = false
}

resource "databricks_grant" "metastore_admin" {
  external_location = databricks_external_location.metastore.name
  principal         = var.admin_user
  privileges        = ["ALL_PRIVILEGES"]
}

resource "databricks_grant" "metastore_credential_admin" {
  storage_credential = var.storage_credential_name
  principal          = var.admin_user
  privileges         = ["ALL_PRIVILEGES", "MANAGE"]
}
