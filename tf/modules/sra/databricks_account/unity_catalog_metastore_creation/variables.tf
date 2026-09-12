variable "metastore_exists" {
  description = "If a metastore exists."
  type        = bool
}

variable "region" {
  description = "AWS region code."
  type        = string
}

variable "custom_metastore_name" {
  description = "Optional name for the Unity Catalog metastore. If null, defaults to <region>-unity-catalog."
  type        = string
  default     = null
  nullable    = true
}

variable "is_serverless" {
  description = "Skip customer-managed metastore S3 when the workspace is serverless-only."
  type        = bool
  default     = false
}

variable "resource_prefix" {
  description = "Prefix for the metastore bucket and IAM role names."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID for the metastore IAM role. Not required when is_serverless is true."
  type        = string
  default     = null
}

variable "databricks_account_id" {
  description = "Databricks account ID used in the metastore bucket policy."
  type        = string
}

variable "aws_iam_partition" {
  type        = string
  description = "AWS partition for IAM ARNs."
  default     = "aws"
}

variable "aws_assume_partition" {
  type        = string
  description = "AWS partition for Unity Catalog assume-role policies."
  default     = "aws"
}

variable "unity_catalog_iam_arn" {
  type        = string
  description = "Unity Catalog IAM ARN for the master role."
  default     = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
}

variable "metastore_bucket_name" {
  description = "Optional S3 bucket name for metastore storage only. Defaults to {resource_prefix}-metastore."
  type        = string
  default     = null
  nullable    = true
}
