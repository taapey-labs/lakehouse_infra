# Unity Catalog metastore (account API), dedicated S3 bucket, and IAM role.
# The storage credential is created on the account so the role trust can use
# Unity Catalog's external_id before the workspace exists.

locals {
  metastore_bucket_name = coalesce(var.metastore_bucket_name, "${var.resource_prefix}-metastore")
  metastore_role_name   = "${var.resource_prefix}-metastore"
  metastore_role_arn    = "arn:${var.aws_iam_partition}:iam::${var.aws_account_id}:role/${local.metastore_role_name}"
  create_metastore_aws  = !var.is_serverless
  create_metastore      = !var.metastore_exists && !var.is_serverless
  metastore_id          = var.metastore_exists ? data.databricks_metastore.this[0].id : databricks_metastore.this[0].id
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

# Existing metastores cannot change storage_root. New metastores use this bucket.
resource "databricks_metastore" "this" {
  count         = local.create_metastore ? 1 : 0
  name          = coalesce(var.custom_metastore_name, "${var.region}-unity-catalog")
  storage_root  = "s3://${aws_s3_bucket.metastore[0].id}/metastore"
  region        = var.region
  force_destroy = true
}

# Account-level credential (predicted IAM role ARN). Databricks returns external_id
# used in the role trust below. New metastores use metastore_data_access as the
# default credential for storage_root; existing metastores cannot change storage_root.
resource "databricks_storage_credential" "metastore" {
  count        = local.create_metastore_aws && !local.create_metastore ? 1 : 0
  metastore_id = local.metastore_id
  name         = "${var.resource_prefix}-metastore-storage-credential"
  aws_iam_role {
    role_arn = local.metastore_role_arn
  }
  comment         = "Account storage credential for the Unity Catalog metastore bucket"
  isolation_mode  = "ISOLATION_MODE_OPEN"
  skip_validation = true
}

resource "databricks_metastore_data_access" "metastore" {
  count        = local.create_metastore ? 1 : 0
  metastore_id = databricks_metastore.this[0].id
  name         = "${var.resource_prefix}-metastore-storage-credential"
  aws_iam_role {
    role_arn = local.metastore_role_arn
  }
  is_default = true
}

data "databricks_aws_unity_catalog_assume_role_policy" "metastore" {
  count                 = local.create_metastore_aws ? 1 : 0
  aws_account_id        = var.aws_account_id
  aws_partition         = var.aws_assume_partition
  role_name             = local.metastore_role_name
  unity_catalog_iam_arn = var.unity_catalog_iam_arn
  external_id = local.create_metastore ? databricks_metastore_data_access.metastore[0].aws_iam_role[0].external_id : databricks_storage_credential.metastore[0].aws_iam_role[0].external_id
}

data "databricks_aws_unity_catalog_policy" "metastore" {
  count          = local.create_metastore_aws ? 1 : 0
  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_assume_partition
  bucket_name    = aws_s3_bucket.metastore[0].id
  role_name      = local.metastore_role_name
}

resource "aws_iam_role" "metastore" {
  count              = local.create_metastore_aws ? 1 : 0
  name               = local.metastore_role_name
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.metastore[0].json
  tags = {
    Name    = local.metastore_role_name
    Project = var.resource_prefix
    Purpose = "unity-catalog-metastore"
  }
}

resource "aws_iam_policy" "metastore" {
  count  = local.create_metastore_aws ? 1 : 0
  name   = "${var.resource_prefix}-metastore-policy"
  policy = data.databricks_aws_unity_catalog_policy.metastore[0].json
}

resource "aws_iam_role_policy_attachment" "metastore" {
  count      = local.create_metastore_aws ? 1 : 0
  role       = aws_iam_role.metastore[0].name
  policy_arn = aws_iam_policy.metastore[0].arn
}

resource "aws_s3_bucket_policy" "metastore" {
  count  = local.create_metastore_aws ? 1 : 0
  bucket = aws_s3_bucket.metastore[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MetastoreRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.metastore[0].arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.metastore[0].arn,
          "${aws_s3_bucket.metastore[0].arn}/*",
        ]
      },
      {
        Sid    = "DatabricksUnityCatalogAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${var.aws_iam_partition}:iam::${var.databricks_aws_account_id}:root"
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.metastore[0].arn,
          "${aws_s3_bucket.metastore[0].arn}/*",
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/DatabricksAccountId" = var.databricks_account_id
          }
        }
      },
    ]
  })
}
