# lakehouse_infra

Terraform starter code to deploy a Databricks serverless workspace on AWS.

## Files

- `versions.tf` - Terraform and provider requirements
- `variables.tf` - Inputs for the Databricks account, workspace name, and AWS region
- `main.tf` - Account-level Databricks workspace deployment
- `outputs.tf` - Workspace identifiers and URL

## Usage

Set the required Databricks authentication environment variables for the account-level provider, then apply Terraform:

```bash
terraform init
terraform apply \
  -var="databricks_account_id=<account-id>" \
  -var="workspace_name=<workspace-name>" \
  -var="aws_region=us-east-1"
```

This configuration creates a Databricks workspace in AWS using `compute_mode = "SERVERLESS"`.

