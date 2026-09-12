# lakehouse_infra

Terraform wrapper around pinned Databricks SRA (`compute_mode = HYBRID`, `network_configuration = custom`) plus a CloudFormation customer VPC that mirrors SRA **isolated** networking.

SRA custom mode does not create a VPC. Isolated-style networking is defined in `cf/vpc_customer.manage.template`, then IDs are passed into Terraform as `custom_*` variables.

See [SRA AWS getting started](https://databricks.github.io/terraform-databricks-sra/docs/usage/AWS/gettingstarted/) (use the **custom** variables, not isolated CIDR variables, in Terraform).

## Files

- `cf/vpc_customer.manage.template` - Customer VPC, PrivateLink, workspace SG
- `tf/main.tf` - SRA module
- `tf/variables.tf` - Inputs, including CloudFormation stack outputs
- `tf/outputs.tf` - Workspace URL and catalog name
- `tf/backend.tf` - S3/DynamoDB state

## 1. CloudFormation customer VPC (isolated-style, custom IDs)

The template matches SRA isolated (`aws/tf/network.tf` and `privatelink.tf`) for a **two-AZ** region such as `us-west-1`:

| Isolated SRA | This template |
| --- | --- |
| No IGW, no NAT | Same |
| Private compute subnets | `WorkspaceSubnetA/B` (`/22`) |
| Intra / PrivateLink subnets | `PrivateLinkSubnetA/B` (`/26`) — **not** workspace subnets |
| S3 gateway + STS + Kinesis + EC2 | STS, Kinesis, and EC2 on PrivateLink subnets |
| Databricks REST + SCC VPCEs | Same, on PrivateLink subnets |
| Workspace SG egress to VPC CIDR + S3 prefix list | Same (plus DNS 53) |
| PrivateLink SG 443/2443/5432/6666/8443–8451 | Same |

Differences from stock isolated SRA (required for classic NPIP):

- REST VPCE keeps AWS private DNS (`ncalifornia.privatelink.cloud.databricks.com`)
- SCC VPCE private DNS is **off**
- Route 53 aliases `tunnel.privatelink.cloud.databricks.com` to the SCC endpoint

Defaults are `10.10.0.0/18` with us-west-1 PrivateLink service names. Changing CIDRs on an existing stack replaces the VPC/subnets/VPCEs; pass the current CIDRs to update in place, or create a new stack.

Deploy (example):

```bash
aws cloudformation deploy \
  --stack-name vpc-customer-manage \
  --template-file cf/vpc_customer.manage.template \
  --parameter-overrides \
    ProjectName=lakehouse \
    AvailabilityZoneA=us-west-1a \
    AvailabilityZoneB=us-west-1c
```

Map stack outputs to SRA:

| CloudFormation output | Terraform variable |
| --- | --- |
| `VpcId` | `custom_vpc_id` |
| `WorkspaceSubnetAId`, `WorkspaceSubnetBId` | `custom_private_subnet_ids` |
| `DatabricksSecurityGroupId` | `custom_sg_id` |
| `DatabricksWorkspaceVpcEndpointId` | `custom_general_access_vpce_id` (AWS `vpce-…`, REST) |
| `DatabricksSccRelayVpcEndpointId` | `custom_scc_relay_vpce_id` (AWS `vpce-…`, SCC) |

Do **not** put PrivateLink subnet IDs in `custom_private_subnet_ids`. Those are for interface endpoints only.

Pass only CloudFormation AWS `vpce-` IDs. Do **not** pass Databricks account-console VPC endpoint UUIDs (MWS). SRA registers those AWS endpoints itself.

The vendored SRA workspace module attaches `databricks_mws_vpc_endpoint.general_access` to `dataplane_relay` and `scc_tunnel_dataplane_relay_access` to `rest_api`. That matches Databricks use_case on this account (SCC AWS VPCE registered as DATAPLANE_RELAY_ACCESS, REST as WORKSPACE_ACCESS). Keep tfvars as they are; do not swap the two AWS IDs to “fix” the rest_api error.

After a stack update that replaces VPCEs, pass the new AWS endpoint IDs into Terraform.

## 2. Terraform SRA workspace

```bash
terraform -chdir=tf init
terraform -chdir=tf apply \
  -var="databricks_account_id=<account-id>" \
  -var="aws_region=us-west-1" \
  -var="custom_vpc_id=vpc-..." \
  -var='custom_private_subnet_ids=["subnet-...","subnet-..."]' \
  -var="custom_sg_id=sg-..." \
  -var="custom_general_access_vpce_id=vpce-..." \
  -var="custom_scc_relay_vpce_id=vpce-..."
```

Auth: AWS credential chain plus `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET` (and matching Terraform variables).

This Databricks account does not support `ingress.cross_workspace_access` on account network policies, so this repo does not create `{prefix}-uc-ingress-np`.

`audit_log_delivery_exists` defaults to `true` so SRA does not recreate `{prefix}-audit-log-delivery-credential` when that MWS credential already exists. Set it to `false` only for a brand-new account that has never had audit log delivery configured.

## Starter SQL warehouse

Terraform manages the workspace **Starter Warehouse** as a serverless PRO SQL warehouse. Size defaults to **`2X-Small`** (instead of Small). Set it in tfvars:

```hcl
sql_warehouse_name           = "Starter Warehouse"
sql_warehouse_cluster_size   = "2X-Small"   # or X-Small, Small, Medium, ...
sql_warehouse_auto_stop_mins = 10
```

If the warehouse already exists, import it before apply:

```bash
terraform -chdir=tf import \
  'module.aws_databricks_sra.module.starter_sql_warehouse.databricks_sql_endpoint.starter' \
  <warehouse-id>
```

## Metastore S3 bucket

HYBRID mode creates a dedicated S3 bucket for Unity Catalog metastore storage only (`{resource_prefix}-metastore` by default). It is not the workspace root bucket or a catalog bucket.

```hcl
metastore_bucket_name = "my-prefix-metastore" # optional override
```

If `metastore_exists = false`, the new metastore uses this bucket as `storage_root`. If the metastore already exists, its storage root cannot be changed; the bucket and IAM role are still created.

## Classic cluster NPIP / ngrok timeout (`tunnel.privatelink.cloud.databricks.com:2443`)

Classic compute over PrivateLink opens an SCC (ngrok) tunnel to the relay VPC endpoint (TCP **2443** FIPS and **6666**). After the stack is current, restart the classic cluster. From a workspace subnet:

```bash
nslookup ncalifornia.privatelink.cloud.databricks.com   # REST VPCE ENIs
nslookup tunnel.privatelink.cloud.databricks.com         # SCC VPCE ENIs (not the REST pair)
nc -zv tunnel.privatelink.cloud.databricks.com 2443
nc -zv tunnel.privatelink.cloud.databricks.com 6666
```
