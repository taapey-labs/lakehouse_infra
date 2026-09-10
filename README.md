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

This Databricks account does not support `ingress.cross_workspace_access` on account network policies, so this repo does not create `{prefix}-uc-ingress-np`.

## Classic cluster NPIP / ngrok timeout (`tunnel.privatelink.cloud.databricks.com:2443`)

Classic compute over PrivateLink opens an SCC (ngrok) tunnel to the relay VPC endpoint. That path uses TCP **2443** (FIPS) as well as **6666**. The customer VPC template must allow:

- Workspace SG egress TCP 2443 and 6666
- PrivateLink endpoint SG ingress TCP 2443 and 6666 from the workspace SG

The workspace/REST VPC endpoint private DNS name is `ncalifornia.privatelink.cloud.databricks.com`. That is **not** the SCC relay. Classic compute looks up `tunnel.privatelink.cloud.databricks.com`. If that name resolves to the REST ENIs, `nc` to 2443/6666 returns **connection refused**.

The template now:

- Leaves REST private DNS on (`ncalifornia.privatelink.cloud.databricks.com`)
- Turns **off** AWS-managed private DNS on the SCC endpoint
- Creates a Route 53 private zone that aliases `tunnel.privatelink.cloud.databricks.com` to the SCC VPC endpoint

Update the `vpc_customer.manage` CloudFormation stack, then restart the classic cluster. From a workspace subnet, confirm the two names resolve to **different** IPs:

```bash
nslookup ncalifornia.privatelink.cloud.databricks.com   # REST VPCE ENIs
nslookup tunnel.privatelink.cloud.databricks.com         # SCC VPCE ENIs (not the REST pair)
nc -zv tunnel.privatelink.cloud.databricks.com 2443      # succeeded, not connection refused
nc -zv tunnel.privatelink.cloud.databricks.com 6666
```

## Additional catalog S3 bucket (existing storage credential)

Terraform creates a new bucket (`{resource_prefix}-data-{workspace_id}` by default) and grants the **existing Unity Catalog storage credential’s IAM role** access on that bucket. No instance profile is created or required.

By default the credential is the SRA workspace catalog one: `{resource_prefix}-catalog-{workspace_id}-storage-credential`, and the IAM role is `{resource_prefix}-catalog-{workspace_id}`. Override with `existing_storage_credential_name` and `existing_storage_credential_role_name` if yours differ.

Also created:

- isolated external location `s3://<bucket>/`
- catalog `lakehouse_data` (override with `additional_catalog_name`)
- `ALL_PRIVILEGES` for `admin_user`

