# Workspace-level Unity Catalog storage credential, IAM role, and external
# location for the dedicated metastore S3 bucket. Must use the workspace host;
# the account API POST /accounts/{id}/metastores/storage-credentials is not
# available on this Databricks account.

locals {
  metastore_role_name = "${var.resource_prefix}-metastore"
}

resource "databricks_storage_credential" "metastore" {
  name = "${var.resource_prefix}-metastore-storage-credential"
  aws_iam_role {
    role_arn = "arn:${var.aws_iam_partition}:iam::${var.aws_account_id}:role/${local.metastore_role_name}"
  }
  comment        = "Storage credential for the Unity Catalog metastore bucket only"
  isolation_mode = "ISOLATION_MODE_OPEN"
}

data "databricks_aws_unity_catalog_assume_role_policy" "metastore" {
  aws_account_id        = var.aws_account_id
  aws_partition         = var.aws_assume_partition
  role_name             = local.metastore_role_name
  unity_catalog_iam_arn = var.unity_catalog_iam_arn
  external_id           = databricks_storage_credential.metastore.aws_iam_role[0].external_id
}

data "databricks_aws_unity_catalog_policy" "metastore" {
  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_assume_partition
  bucket_name    = var.metastore_bucket_id
  role_name      = local.metastore_role_name
}

resource "aws_iam_role" "metastore" {
  name               = local.metastore_role_name
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.metastore.json
  tags = {
    Name    = local.metastore_role_name
    Project = var.resource_prefix
    Purpose = "unity-catalog-metastore"
  }
}

resource "aws_iam_policy" "metastore" {
  name   = "${var.resource_prefix}-metastore-policy"
  policy = data.databricks_aws_unity_catalog_policy.metastore.json
}

resource "aws_iam_role_policy_attachment" "metastore" {
  role       = aws_iam_role.metastore.name
  policy_arn = aws_iam_policy.metastore.arn
}

resource "aws_s3_bucket_policy" "metastore" {
  bucket = var.metastore_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MetastoreRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.metastore.arn
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
          var.metastore_bucket_arn,
          "${var.metastore_bucket_arn}/*",
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
          var.metastore_bucket_arn,
          "${var.metastore_bucket_arn}/*",
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
  create_duration = "60s"
  depends_on = [
    aws_iam_role_policy_attachment.metastore,
    aws_s3_bucket_policy.metastore,
  ]
}

resource "databricks_external_location" "metastore" {
  name            = "${var.resource_prefix}-metastore-external-location"
  url             = "s3://${var.metastore_bucket_id}/"
  credential_name = databricks_storage_credential.metastore.id
  comment         = "Dedicated Unity Catalog metastore storage bucket"
  isolation_mode  = "ISOLATION_MODE_OPEN"
  skip_validation = true
  depends_on      = [time_sleep.metastore_iam]
}

resource "databricks_grant" "metastore_admin" {
  external_location = databricks_external_location.metastore.name
  principal         = var.admin_user
  privileges        = ["ALL_PRIVILEGES"]
}
