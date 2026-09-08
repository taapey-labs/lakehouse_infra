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

This configuration deploys a Databricks workspace in AWS with `compute_mode = "HYBRID"` and `network_configuration = "custom"`.

## Unity Catalog 403 (`Unauthorized network access to workspace`)

SRA attaches a restrictive network policy with cross-workspace ingress set to `RESTRICTED_ACCESS` and an empty allow list. Unity Catalog backend calls into the workspace then fail with HTTP 403 / `KCUC4`.

Workspace `7474654246419237` is allow-listed as a cross-workspace ingress source via `cross_workspace_ingress_allowed_workspace_ids`. Re-apply Terraform so the `{resource_prefix}-np` policy picks up the rule. To allow additional source workspaces, pass more IDs in that variable.

