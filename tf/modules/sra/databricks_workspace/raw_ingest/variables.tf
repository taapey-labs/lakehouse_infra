variable "resource_prefix" {
  type        = string
  description = "Prefix for the raw ingest bucket and IAM role names."
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID where the ingest role is created."
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks account ID used in the bucket policy."
}

variable "aws_iam_partition" {
  type        = string
  default     = "aws"
  description = "AWS partition for IAM ARNs."
}

variable "aws_assume_partition" {
  type        = string
  default     = "aws"
  description = "AWS partition for Unity Catalog assume-role policies."
}

variable "unity_catalog_iam_arn" {
  type        = string
  default     = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
  description = "Unity Catalog IAM ARN for the master role."
}

variable "admin_user" {
  type        = string
  description = "Workspace admin granted ALL_PRIVILEGES on the raw ingest external location."
}

variable "raw_ingest_bucket_name" {
  type        = string
  default     = null
  nullable    = true
  description = "S3 bucket for raw files landed outside Databricks. Defaults to {resource_prefix}-raw-ingest."
}

variable "raw_ingest_trusted_principal_arns" {
  type        = list(string)
  default     = []
  description = "AWS principal ARNs (roles/users/accounts) that may assume the ingest role and write objects to the bucket."
}
