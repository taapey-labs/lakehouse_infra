# Dedicated S3 bucket for Unity Catalog metastore storage only (not workspace root, not catalog).
# HYBRID only. When creating a metastore, it is used as storage_root plus default data access.

locals {
  metastore_bucket_name = coalesce(var.metastore_bucket_name, "${var.resource_prefix}-metastore")
  metastore_role_name   = "${var.resource_prefix}-metastore"
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

resource "databricks_storage_credential" "metastore" {
  count = local.create_metastore_aws ? 1 : 0
  name  = "${var.resource_prefix}-metastore-storage-credential"
  aws_iam_role {
    role_arn = "arn:${var.aws_iam_partition}:iam::${var.aws_account_id}:role/${local.metastore_role_name}"
  }
  comment        = "Storage credential for the Unity Catalog metastore bucket only"
  isolation_mode = "ISOLATION_MODE_OPEN"
}

data "databricks_aws_unity_catalog_assume_role_policy" "metastore" {
  count                 = local.create_metastore_aws ? 1 : 0
  aws_account_id        = var.aws_account_id
  aws_partition         = var.aws_assume_partition
  role_name             = local.metastore_role_name
  unity_catalog_iam_arn = var.unity_catalog_iam_arn
  external_id           = databricks_storage_credential.metastore[0].aws_iam_role[0].external_id
}

data "databricks_aws_unity_catalog_policy" "metastore" {
  count          = local.create_metastore_aws ? 1 : 0
  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_assume_partition
  bucket_name    = local.metastore_bucket_name
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
  count      = local.create_metastore_aws ? 1 : 0
  bucket     = aws_s3_bucket.metastore[0].id
  depends_on = [aws_s3_bucket_public_access_block.metastore]

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
          AWS = "arn:${var.aws_iam_partition}:iam::414351767826:root"
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

resource "time_sleep" "metastore_iam" {
  count           = local.create_metastore ? 1 : 0
  create_duration = "30s"
  depends_on = [
    aws_iam_role_policy_attachment.metastore,
    aws_s3_bucket_policy.metastore,
  ]
}

resource "databricks_metastore" "this" {
  count         = local.create_metastore ? 1 : 0
  name          = coalesce(var.custom_metastore_name, "${var.region}-unity-catalog")
  region        = var.region
  storage_root  = "s3://${aws_s3_bucket.metastore[0].id}/"
  force_destroy = true
  depends_on    = [time_sleep.metastore_iam]
}

resource "databricks_metastore_data_access" "this" {
  count        = local.create_metastore ? 1 : 0
  metastore_id = databricks_metastore.this[0].id
  name         = "${var.resource_prefix}-metastore-data-access"
  is_default   = true
  aws_iam_role {
    role_arn = aws_iam_role.metastore[0].arn
  }
  depends_on = [time_sleep.metastore_iam]
}
