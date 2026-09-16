# lakehouse_infra

Terraform wrapper around pinned Databricks SRA (`compute_mode = HYBRID`, `network_configuration = custom`) plus a CloudFormation customer VPC with **public/private subnets, an Internet Gateway, and a NAT Gateway** so classic clusters can initialize over the internet.

SRA custom mode does not create a VPC. Networking is defined in `cf/vpc_customer.manage.template`, then IDs are passed into Terraform as `custom_*` variables.

See [SRA AWS getting started](https://databricks.github.io/terraform-databricks-sra/docs/usage/AWS/gettingstarted/) (use the **custom** variables, not isolated CIDR variables, in Terraform).

## Files

- `cf/vpc_customer.manage.template` - Customer VPC, PrivateLink, workspace SG
- `tf/main.tf` - SRA module
- `tf/variables.tf` - Inputs, including CloudFormation stack outputs
- `tf/outputs.tf` - Workspace URL, catalog, metastore bucket, raw ingest bucket/role
- `tf/backend.tf` - S3/DynamoDB state

## 1. CloudFormation customer VPC (public/private + NAT)

The template is a two-AZ playground VPC (`us-west-1`): Databricks classic compute stays in **private** subnets; NAT lives in a **public** subnet.

| Piece | This template |
| --- | --- |
| Internet Gateway | Attached to the VPC |
| Public subnets | `PublicSubnetA/B` (`/24`), IGW route |
| NAT Gateway | Single public NAT in `PublicSubnetA` (Elastic IP) |
| Private compute subnets | `WorkspaceSubnetA/B` (`/22`), default route `0.0.0.0/0` → NAT |
| Intra / PrivateLink subnets | `PrivateLinkSubnetA/B` (`/26`) — **not** workspace subnets |
| S3 gateway + STS + Kinesis + EC2 | STS, Kinesis, and EC2 on PrivateLink subnets |
| Databricks REST + SCC VPCEs | Same, on PrivateLink subnets (existing SRA custom IDs) |
| Workspace SG | Egress TCP/UDP self; TCP `0.0.0.0/0` on 443, 3306, 53, 6666, 2443, 5432, and **each** of 8443–8451 (Databricks compute-config check); UDP 53; HTTP 80; S3 prefix list; dest-SG to PrivateLink SG |
| PrivateLink SG 443/2443/5432/6666/8443–8451 | Ingress from workspace SG |

PrivateLink is kept so the current workspace registration does not break. NAT plus internet SG egress is the path for control-plane and AWS API traffic that is not pinned to a VPC endpoint.

Also:

- REST VPCE (`vpce-svc-09bb6ca26208063f2`) keeps AWS private DNS (`ncalifornia.privatelink.cloud.databricks.com`)
- SCC VPCE (`vpce-svc-04cb91f9372b792fe`) private DNS is **off**
- Dedicated Route 53 private hosted zones (same as PR #31; not a `cloud.databricks.com` apex):
  - `tunnel.privatelink.cloud.databricks.com` → **SCC** VPCE
  - `dbc-541c1fdc-07c5.cloud.databricks.com` → **REST** VPCE
  - `dbc-541c1fdc-07c5.privatelink.cloud.databricks.com` → **REST** VPCE

Do **not** keep a private hosted zone for the apex `cloud.databricks.com` associated with the VPC. That zone NXDOMAINs other control-plane names and brings back `BOOTSTRAP_TIMEOUT`. After this stack update, delete or disassociate leftover apex zone `Z03487763H91UHKUM9J6C`. If CloudFormation fails to create a dedicated zone, that FQDN zone already exists — import it or delete the leftover, then retry.

From a host in the VPC:

```text
nslookup ncalifornia.privatelink.cloud.databricks.com       # REST ENIs
nslookup tunnel.privatelink.cloud.databricks.com            # SCC ENIs
nslookup dbc-541c1fdc-07c5.cloud.databricks.com             # REST ENIs, not SCC
nslookup dbc-541c1fdc-07c5.privatelink.cloud.databricks.com  # REST ENIs, not SCC
```

`tunnel.privatelink.cloud.databricks.com` must **not** share IPs with the REST names. After the stack update, **restart the classic cluster**.

Defaults are `10.10.0.0/18` with us-west-1 PrivateLink service names. Changing **existing** CIDRs on a stack replaces those subnets; adding the public CIDRs `10.10.8.0/24` and `10.10.9.0/24` is an in-place update if those blocks are free.

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

After this NAT/IGW stack update, **restart the classic cluster**. Terraform does not need to change unless subnet or VPCE IDs were replaced. Do **not** put public subnet IDs in `custom_private_subnet_ids`.

The Databricks compute-config warning `Egress rules in the Security Group sg-… are not configured correctly` is this CloudFormation workspace SG (`custom_sg_id`), not Unity Catalog. `terraform apply` does not change it in `custom` network mode. Update the `vpc_customer.manage` stack, then refresh Compute configuration. Required TCP to `0.0.0.0/0`: 443, 3306, 53, 6666, 2443, 5432, and each of 8443–8451; plus UDP 53.

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

This Databricks account **rejects** `ingress.cross_workspace_access` on custom network policies. Terraform **does not create** `{prefix}-np` (`sss-aws-lakehouse-np`). Apply **destroys** that policy if it still exists. The workspace is bound to Databricks **`default-policy`**. If apply cannot delete the policy because the workspace is still attached, apply again after the workspace network option shows `default-policy`.

`audit_log_delivery_exists` defaults to `true` so SRA does not recreate `{prefix}-audit-log-delivery-credential` when that MWS credential already exists. Set it to `false` only for a brand-new account that has never had audit log delivery configured.

## Starter SQL warehouse

Terraform manages the workspace **Starter Warehouse** (Pro, size **`2X-Small`** by default). If a warehouse with that name already exists, it is imported into state instead of creating a second one.

```hcl
sql_warehouse_name           = "Starter Warehouse"
sql_warehouse_cluster_size   = "2X-Small"   # or X-Small, Small, Medium, ...
sql_warehouse_auto_stop_mins = 10
```

## Metastore S3 bucket and IAM role

HYBRID mode creates a dedicated S3 bucket (`{resource_prefix}-metastore`) and IAM role (`{resource_prefix}-metastore`) in the **AWS account**, next to the Unity Catalog **account** metastore. They are not the workspace root bucket or a catalog bucket.

```hcl
metastore_bucket_name = "my-prefix-metastore" # optional override
```

If `metastore_exists = false`, the account metastore is created with `storage_root = s3://{bucket}/metastore` and a default `databricks_metastore_data_access` on that IAM role. If the metastore already exists, its storage root cannot be changed; the bucket, IAM role, and an account storage credential are still created. After the workspace is assigned, Terraform adds an OPEN external location on `s3://{bucket}/base`.

## Raw ingest S3 bucket and IAM role

HYBRID mode creates a landing bucket for files written **outside** Databricks (`{resource_prefix}-raw-ingest` by default) and IAM role `{resource_prefix}-raw-ingest`. Unity Catalog gets a storage credential and OPEN external location on `s3://<bucket>/`.

External producers should assume the ingest role (preferred) or be listed so they can `PutObject` directly. Pass their IAM role/user/account ARNs:

```hcl
raw_ingest_bucket_name            = "my-prefix-raw-ingest" # optional override
raw_ingest_trusted_principal_arns = [
  "arn:aws:iam::123456789012:role/producer-role",
]
```

If `raw_ingest_trusted_principal_arns` is empty, only Databricks Unity Catalog can use the role until those ARNs are added. Outputs: `raw_ingest_bucket`, `raw_ingest_role_arn`, `raw_ingest_external_location`.

## Classic cluster NPIP / ngrok timeout (`tunnel.privatelink.cloud.databricks.com:2443`)

Classic compute over PrivateLink opens an SCC (ngrok) tunnel to `tunnel.privatelink.cloud.databricks.com` (TCP **2443** FIPS and **6666**). If that name is answered by the REST VPCE zone, the driver hits `BOOTSTRAP_TIMEOUT` / “check network connectivity from the data plane to the control plane” because 2443/6666 are refused on the REST NLB.

The customer VPC template disables AWS private DNS on the SCC endpoint and uses dedicated private hosted zones (PR #31): `tunnel.privatelink` → SCC VPCE, workspace `dbc-*` public and privatelink names → REST VPCE. After the stack update, disassociate or delete leftover `cloud.databricks.com` apex PHZ `Z03487763H91UHKUM9J6C`, then restart the classic cluster. From a workspace subnet:

```bash
nslookup ncalifornia.privatelink.cloud.databricks.com   # REST VPCE ENIs
nslookup dbc-541c1fdc-07c5.cloud.databricks.com          # REST VPCE ENIs
nslookup dbc-541c1fdc-07c5.privatelink.cloud.databricks.com
nslookup tunnel.privatelink.cloud.databricks.com         # SCC VPCE ENIs (not the REST pair)
nc -zv tunnel.privatelink.cloud.databricks.com 2443
nc -zv tunnel.privatelink.cloud.databricks.com 6666
```
