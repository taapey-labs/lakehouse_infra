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

## Classic cluster NPIP / ngrok timeout (`tunnel.privatelink.cloud.databricks.com:2443`)

Classic compute over PrivateLink opens an SCC (ngrok) tunnel to the relay VPC endpoint. That path uses TCP **2443** (FIPS) as well as **6666**. The customer VPC template must allow:

- Workspace SG egress TCP 2443 and 6666
- PrivateLink endpoint SG ingress TCP 2443 and 6666 from the workspace SG

Update the `vpc_customer.manage` CloudFormation stack, then restart the classic cluster. From an EC2 instance in a workspace subnet, confirm:

```bash
nslookup tunnel.privatelink.cloud.databricks.com   # private VPCE IPs, not public
nc -zv tunnel.privatelink.cloud.databricks.com 2443
nc -zv tunnel.privatelink.cloud.databricks.com 6666
```

