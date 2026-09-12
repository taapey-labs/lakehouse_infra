# Unity Catalog metastore (account API) plus a dedicated S3 bucket for that
# storage. IAM role and storage credential are created later with the workspace
# provider: this account has no POST /accounts/.../metastores/storage-credentials.

locals {
  metastore_bucket_name = coalesce(var.metastore_bucket_name, "${var.resource_prefix}-metastore")
  create_metastore_aws  = !var.is_serverless
  create_metastore      = !var.metastore_exists && !var.is_serverless
}

data "databricks_metastore" "this" {
  count  = var.metastore_exists ? 1 : 0
  region = var.region
}

resource "aws_s3_bucket" "metastore" {
  count         = local.create_metastore_aws ? 1 : 0
  bucket        = local.metastore_bucket_name
  force_destroy = false
  tags = {
    Name    = local.metastore_bucket_name
    Project = var.resource_prefix
    Purpose = "unity-catalog-metastore"
  }
}

resource "aws_s3_bucket_versioning" "metastore" {
  count  = local.create_metastore_aws ? 1 : 0
  bucket = aws_s3_bucket.metastore[0].id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metastore" {
  count  = local.create_metastore_aws ? 1 : 0
  bucket = aws_s3_bucket.metastore[0].id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "metastore" {
  count                   = local.create_metastore_aws ? 1 : 0
  bucket                  = aws_s3_bucket.metastore[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Existing metastores cannot change storage_root. New metastores omit it here so
# we do not need an account-level storage credential (unsupported on this shard).
resource "databricks_metastore" "this" {
  count         = local.create_metastore ? 1 : 0
  name          = coalesce(var.custom_metastore_name, "${var.region}-unity-catalog")
  region        = var.region
  force_destroy = true
}
