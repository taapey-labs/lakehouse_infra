terraform {
  required_version = ">= 1.11.0"
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

provider "databricks" {
  alias         = "workspace"
  host          = var.account_console
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
