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
  description = "Prefix for the metastore bucket name."
  type        = string
}

variable "metastore_bucket_name" {
  description = "Optional S3 bucket name for metastore storage only. Defaults to {resource_prefix}-metastore."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_account_id" {
  description = "AWS account ID where the metastore IAM role is created."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID used in the metastore bucket policy."
  type        = string
}

variable "databricks_aws_account_id" {
  description = "Databricks AWS account ID (414351767826 on commercial) for the metastore bucket policy."
  type        = string
}

variable "aws_iam_partition" {
  description = "AWS partition for IAM ARNs."
  type        = string
  default     = "aws"
}

variable "aws_assume_partition" {
  description = "AWS partition for Unity Catalog assume-role policies."
  type        = string
  default     = "aws"
}

variable "unity_catalog_iam_arn" {
  description = "Unity Catalog IAM ARN for the master role."
  type        = string
}
