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
