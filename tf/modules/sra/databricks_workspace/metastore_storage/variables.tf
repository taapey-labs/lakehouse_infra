variable "resource_prefix" {
  type        = string
  description = "Prefix for the metastore IAM role and Unity Catalog credential names."
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID where the metastore IAM role is created."
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
  description = "Workspace admin granted ALL_PRIVILEGES on the metastore external location."
}

variable "metastore_bucket_id" {
  type        = string
  description = "Name of the dedicated metastore S3 bucket."
}

variable "metastore_bucket_arn" {
  type        = string
  description = "ARN of the dedicated metastore S3 bucket."
}
