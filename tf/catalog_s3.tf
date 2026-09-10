# Additional Unity Catalog catalog on a new S3 bucket, using an existing
# storage credential (no instance profile). Does not replace the SRA workspace catalog.

locals {
  additional_catalog_bucket_name = coalesce(
    var.additional_catalog_bucket_name,
    "${var.resource_prefix}-data-${var.workspace_id}"
  )
  existing_storage_credential_name = coalesce(
    var.existing_storage_credential_name,
    "${var.resource_prefix}-catalog-${var.workspace_id}-storage-credential"
  )
  existing_credential_role_arn = data.databricks_storage_credential.existing.storage_credential_info[0].aws_iam_role[0].role_arn
  existing_credential_role_name = element(split("/", local.existing_credential_role_arn), length(split("/", local.existing_credential_role_arn)) - 1)
}

data "databricks_storage_credential" "existing" {
  provider = databricks.workspace
  name     = local.existing_storage_credential_name
  depends_on = [module.databricks_sra]
}

resource "aws_s3_bucket" "additional_catalog" {
  bucket        = local.additional_catalog_bucket_name
  force_destroy = false

  tags = {
    Name    = local.additional_catalog_bucket_name
    Project = var.resource_prefix
    Purpose = "unity-catalog"
  }
}

resource "aws_s3_bucket_public_access_block" "additional_catalog" {
  bucket                  = aws_s3_bucket.additional_catalog.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "additional_catalog" {
  bucket = aws_s3_bucket.additional_catalog.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "additional_catalog" {
  bucket     = aws_s3_bucket.additional_catalog.id
  depends_on = [aws_s3_bucket_public_access_block.additional_catalog]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ExistingStorageCredentialRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = local.existing_credential_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
        ]
        Resource = [
          aws_s3_bucket.additional_catalog.arn,
          "${aws_s3_bucket.additional_catalog.arn}/*",
        ]
      },
      {
        Sid    = "DatabricksUnityCatalogAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
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
          aws_s3_bucket.additional_catalog.arn,
          "${aws_s3_bucket.additional_catalog.arn}/*",
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

resource "aws_iam_role_policy" "additional_catalog_s3" {
  name = "${var.resource_prefix}-data-catalog-s3"
  role = local.existing_credential_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CatalogBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
        ]
        Resource = [
          aws_s3_bucket.additional_catalog.arn,
          "${aws_s3_bucket.additional_catalog.arn}/*",
        ]
      },
    ]
  })
}

resource "databricks_external_location" "additional_catalog" {
  provider        = databricks.workspace
  name            = "${var.additional_catalog_name}-external-location"
  url             = "s3://${aws_s3_bucket.additional_catalog.id}/"
  credential_name = data.databricks_storage_credential.existing.name
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  comment         = "External location for catalog ${var.additional_catalog_name}"
  skip_validation = true

  depends_on = [
    aws_iam_role_policy.additional_catalog_s3,
    aws_s3_bucket_policy.additional_catalog,
  ]
}

resource "databricks_catalog" "additional" {
  provider       = databricks.workspace
  name           = var.additional_catalog_name
  comment        = "Catalog backed by s3://${aws_s3_bucket.additional_catalog.id}/ via storage credential ${local.existing_storage_credential_name}"
  isolation_mode = "ISOLATED"
  storage_root   = "s3://${aws_s3_bucket.additional_catalog.id}/"
  properties = {
    purpose = "additional-catalog"
  }

  depends_on = [databricks_external_location.additional_catalog]
}

resource "databricks_grant" "additional_catalog_admin" {
  provider   = databricks.workspace
  catalog    = databricks_catalog.additional.name
  principal  = var.admin_user
  privileges = ["ALL_PRIVILEGES"]
}