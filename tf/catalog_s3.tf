# Additional Unity Catalog catalog plus a dedicated S3 bucket.
# Does not create a storage credential or external location; the catalog uses
# metastore default storage. The bucket is available to attach later.
# Does not replace the SRA workspace catalog.

locals {
  additional_catalog_bucket_name = coalesce(
    var.additional_catalog_bucket_name,
    "${var.resource_prefix}-data-${var.workspace_id}"
  )
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

resource "databricks_catalog" "additional" {
  provider       = databricks.workspace
  name           = var.additional_catalog_name
  comment        = "Catalog ${var.additional_catalog_name}; dedicated bucket s3://${aws_s3_bucket.additional_catalog.id}/ is provisioned without a storage credential or external location"
  isolation_mode = "OPEN"
  properties = {
    purpose = "additional-catalog"
  }
}

resource "databricks_grant" "additional_catalog_admin" {
  provider   = databricks.workspace
  catalog    = databricks_catalog.additional.name
  principal  = var.admin_user
  privileges = ["ALL_PRIVILEGES"]
}
