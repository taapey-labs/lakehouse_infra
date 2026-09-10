terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.76, < 7.0" # must satisfy the databricks_sra module's constraint too
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.121" # must satisfy the databricks_sra module's constraint too
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Account-level provider used to attach a UC-compatible network policy after SRA.
# SRA still declares its own nested aws/databricks providers for workspace create.
provider "databricks" {
  alias         = "accounts"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

provider "databricks" {
  alias         = "workspace"
  host          = module.databricks_sra.workspace_host
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
