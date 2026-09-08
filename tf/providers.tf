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

# The databricks_sra module (in main.tf) configures its own aws/databricks providers
# internally and authenticates via DATABRICKS_CLIENT_ID/DATABRICKS_CLIENT_SECRET env vars.
