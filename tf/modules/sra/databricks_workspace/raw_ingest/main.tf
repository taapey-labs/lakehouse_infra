# S3 landing zone for raw data written outside Databricks, plus an IAM role
# that external principals can assume to write and Databricks Unity Catalog
# can assume to ingest.

locals {
  raw_ingest_bucket_name = coalesce(var.raw_ingest_bucket_name, "${var.resource_prefix}-raw-ingest")
  raw_ingest_role_name   = "${var.resource_prefix}-raw-ingest"
}

resource "aws_s3_bucket" "raw_ingest" {
  bucket        = local.raw_ingest_bucket_name
  force_destroy = false
  tags = {
    Name    = local.raw_ingest_bucket_name
    Project = var.resource_prefix
    Purpose = "raw-ingest"
  }
}

resource "aws_s3_bucket_versioning" "raw_ingest" {
  bucket = aws_s3_bucket.raw_ingest.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_ingest" {
  bucket = aws_s3_bucket.raw_ingest.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw_ingest" {
  bucket                  = aws_s3_bucket.raw_ingest.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cross-account PutObject must land as bucket-owner objects so Databricks can read them.
resource "aws_s3_bucket_ownership_controls" "raw_ingest" {
  bucket = aws_s3_bucket.raw_ingest.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "databricks_storage_credential" "raw_ingest" {
  name = "${var.resource_prefix}-raw-ingest-storage-credential"
  aws_iam_role {
    role_arn = "arn:${var.aws_iam_partition}:iam::${var.aws_account_id}:role/${local.raw_ingest_role_name}"
  }
  comment        = "Credential for raw ingest landing bucket (external writers + Databricks ingest)"
  isolation_mode = "ISOLATION_MODE_OPEN"
}

data "databricks_aws_unity_catalog_assume_role_policy" "raw_ingest" {
  aws_account_id        = var.aws_account_id
  aws_partition         = var.aws_assume_partition
  role_name             = local.raw_ingest_role_name
  unity_catalog_iam_arn = var.unity_catalog_iam_arn
  external_id           = databricks_storage_credential.raw_ingest.aws_iam_role[0].external_id
}

data "aws_iam_policy_document" "raw_ingest_trust" {
  source_policy_documents = [
    data.databricks_aws_unity_catalog_assume_role_policy.raw_ingest.json
  ]

  dynamic "statement" {
    for_each = var.raw_ingest_trusted_principal_arns
    content {
      sid     = "ExternalRawIngest${statement.key}"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
    }
  }
}

data "databricks_aws_unity_catalog_policy" "raw_ingest" {
  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_assume_partition
  bucket_name    = local.raw_ingest_bucket_name
  role_name      = local.raw_ingest_role_name
}

resource "aws_iam_role" "raw_ingest" {
  name               = local.raw_ingest_role_name
  description        = "Assume this role to land raw files in s3://${local.raw_ingest_bucket_name}/; Databricks uses it to ingest"
  assume_role_policy = data.aws_iam_policy_document.raw_ingest_trust.json
  tags = {
    Name    = local.raw_ingest_role_name
    Project = var.resource_prefix
    Purpose = "raw-ingest"
  }
}

resource "aws_iam_policy" "raw_ingest" {
  name        = "${var.resource_prefix}-raw-ingest-policy"
  description = "Read/write the raw ingest landing bucket"
  policy      = data.databricks_aws_unity_catalog_policy.raw_ingest.json
}

resource "aws_iam_role_policy_attachment" "raw_ingest" {
  role       = aws_iam_role.raw_ingest.name
  policy_arn = aws_iam_policy.raw_ingest.arn
}

resource "aws_s3_bucket_policy" "raw_ingest" {
  bucket     = aws_s3_bucket.raw_ingest.id
  depends_on = [
    aws_s3_bucket_public_access_block.raw_ingest,
    aws_s3_bucket_ownership_controls.raw_ingest,
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "RawIngestRoleAccess"
          Effect = "Allow"
          Principal = {
            AWS = aws_iam_role.raw_ingest.arn
          }
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation",
            "s3:AbortMultipartUpload",
            "s3:ListBucketMultipartUploads",
          ]
          Resource = [
            aws_s3_bucket.raw_ingest.arn,
            "${aws_s3_bucket.raw_ingest.arn}/*",
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
            aws_s3_bucket.raw_ingest.arn,
            "${aws_s3_bucket.raw_ingest.arn}/*",
          ]
          Condition = {
            StringEquals = {
              "aws:PrincipalTag/DatabricksAccountId" = var.databricks_account_id
            }
          }
        },
      ],
      [
        for i, arn in var.raw_ingest_trusted_principal_arns : {
          Sid    = "ExternalWriter${i}"
          Effect = "Allow"
          Principal = {
            AWS = arn
          }
          Action = [
            "s3:PutObject",
            "s3:AbortMultipartUpload",
            "s3:ListBucket",
            "s3:GetBucketLocation",
          ]
          Resource = [
            aws_s3_bucket.raw_ingest.arn,
            "${aws_s3_bucket.raw_ingest.arn}/*",
          ]
        }
      ]
    )
  })
}

resource "time_sleep" "raw_ingest_iam" {
  create_duration = "60s"
  depends_on = [
    aws_iam_role_policy_attachment.raw_ingest,
    aws_s3_bucket_policy.raw_ingest,
  ]
}

resource "databricks_external_location" "raw_ingest" {
  name            = "${var.resource_prefix}-raw-ingest-external-location"
  url             = "s3://${aws_s3_bucket.raw_ingest.id}/"
  credential_name = databricks_storage_credential.raw_ingest.id
  comment         = "Landing zone for raw data ingested from outside Databricks"
  isolation_mode  = "ISOLATION_MODE_OPEN"
  skip_validation = true
  depends_on      = [time_sleep.raw_ingest_iam]
}

resource "databricks_grant" "raw_ingest_admin" {
  external_location = databricks_external_location.raw_ingest.name
  principal         = var.admin_user
  privileges        = ["ALL_PRIVILEGES"]
}
