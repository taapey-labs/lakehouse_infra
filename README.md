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
| Workspace SG | Egress TCP/UDP self; TCP `0.0.0.0/0` on 443, 3306, 53, 6666, 2443, 5432, and **each** of 8443–8451; UDP 53; HTTP 80; S3 prefix list; dest-SG to PrivateLink SG; **ingress TCP 1024–65535 from S3 prefix list** (gateway return); ICMP 3/4 PMTU |
| PrivateLink SG 443/2443/5432/6666/8443–8451 | Ingress from workspace SG |
| VPC Flow Logs | VPC-wide, CloudWatch `/vpc/{ProjectName}/flow-logs`, **REJECT** by default (SG/NACL denials). Parameter `FlowLogTrafficType` can be `ACCEPT` or `ALL`. |
| Network ACL | Allow-all inbound and outbound `0.0.0.0/0` on every subnet (Databricks customer-managed VPC). NACLs are stateless; without inbound ephemeral ALLOW, S3/NAT replies (`srcport=443`, `dstport=1024-65535`) show as Flow Log REJECT. |

PrivateLink is kept so the current workspace registration does not break. NAT plus internet SG egress is the path for control-plane and AWS API traffic that is not pinned to a VPC endpoint.

Also:

- REST VPCE (`vpce-svc-09bb6ca26208063f2`) keeps AWS private DNS (`ncalifornia.privatelink.cloud.databricks.com`)
- SCC VPCE (`vpce-svc-04cb91f9372b792fe`) private DNS is **off**
- Dedicated Route 53 private hosted zones (not a `cloud.databricks.com` apex):
  - `tunnel.privatelink.cloud.databricks.com` → **SCC** VPCE
  - `dbc-541c1fdc-07c5.privatelink.cloud.databricks.com` → **REST** VPCE
- Do **not** private-host `dbc-541c1fdc-07c5.cloud.databricks.com`. Classic compute calls that **public** name on TCP **8443–8451** (control plane API and UC logging). The REST VPCE NLB only accepts **443**, so a PHZ that maps it to `10.10.1.x` yields `Connection refused`. Let it resolve to public Databricks IPs and egress via NAT.

Do **not** keep a private hosted zone for the apex `cloud.databricks.com` associated with the VPC. That zone NXDOMAINs other control-plane names and brings back `BOOTSTRAP_TIMEOUT`. After this stack update, delete or disassociate leftover apex zone `Z03487763H91UHKUM9J6C`. If CloudFormation fails to create a dedicated zone, that FQDN zone already exists — import it or delete the leftover, then retry.

From a host in the VPC:

```text
nslookup ncalifornia.privatelink.cloud.databricks.com       # REST ENIs
nslookup tunnel.privatelink.cloud.databricks.com            # SCC ENIs
nslookup dbc-541c1fdc-07c5.privatelink.cloud.databricks.com  # REST ENIs, not SCC
nslookup dbc-541c1fdc-07c5.cloud.databricks.com             # public IPs via NAT, not 10.10.1.x
nc -zv dbc-541c1fdc-07c5.cloud.databricks.com 8443
nc -zv dbc-541c1fdc-07c5.privatelink.cloud.databricks.com 443
```

`tunnel.privatelink.cloud.databricks.com` must **not** share IPs with the REST names. After the stack update, **restart the classic cluster**.

Defaults are `10.10.0.0/18` with us-west-1 PrivateLink service names. Changing **existing** CIDRs on a stack replaces those subnets; adding the public CIDRs `10.10.8.0/24` and `10.10.9.0/24` is an in-place update if those blocks are free.

Deploy (example):

```bash
aws cloudformation deploy \
  --stack-name vpc-customer-manage \
  --template-file cf/vpc_customer.manage.template \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ProjectName=lakehouse \
    AvailabilityZoneA=us-west-1a \
    AvailabilityZoneB=us-west-1c
```

REJECT flow logs land in CloudWatch Logs `/vpc/lakehouse/flow-logs` (14-day retention). `action=REJECT` is a security-group or NACL drop, not Unity Catalog KCUC4. Example:

```bash
aws logs filter-log-events \
  --log-group-name /vpc/lakehouse/flow-logs \
  --filter-pattern '"REJECT"'
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

This Databricks account **rejects** `ingress.cross_workspace_access` on custom network policies. Unity Catalog `checkPathAccess` (including `dbutils.fs.ls` on S3) then returns **KCUC4** `Unauthorized network access to workspace: 7474647671578063`. That is **not** S3, IAM, instance profiles, the S3 gateway route table, or the compute-config SG warning.

Terraform always sets the workspace network option to **`default-policy`** and does **not** create `{prefix}-np`. Apply **destroys** `sss-aws-lakehouse-np` after that assignment. `workspace_network_policy_id` in tfvars is ignored.

Confirm in the account console: **Workspaces → sss-aws-lakehouse** (id `7474647671578063`) → Network policy. It must say **`default-policy`**. Editing **Security → default-policy** (“Any workspaces with no policy attached”) does **not** attach it while `sss-aws-lakehouse-np` is still assigned. Then retry `dbutils.fs.ls`.

### KCUC4 on **classic** compute — private-DNS override of the workspace URL (incident postmortem)

Symptom: `SHOW CATALOGS` / `LIST` / `dbutils.fs.ls` / `saveAsTable` return **KCUC4** `Unauthorized network access to workspace: 7474647671578063` **only on classic compute** (classic clusters and **Pro/classic** SQL warehouses), while the Catalog Explorer UI (direct UC REST) still works. `SELECT 1` on the same classic warehouse **succeeds**, so the compute is healthy — only its Unity Catalog calls fail. Note: this account was **not** eligible for serverless, so "serverless as a workaround" was not available.

Root cause (confirmed by resolving the workspace URL from inside the cluster): a **Route 53 private hosted zone for the public workspace URL** (`dbc-<deployment-id>.cloud.databricks.com`) overrode DNS so the workspace URL resolved to a **private** VPC-endpoint IP (e.g. `10.10.6.59` / `10.10.4.249`) instead of public Databricks IPs via NAT. That endpoint serves **443 only** (8443–8451 refused) and is **not authorized** for the workspace front end, so classic-compute UC REST calls to it returned HTTP 403 `Unauthorized network access to workspace`. This is exactly the state the "Do not private-host `dbc-*.cloud.databricks.com`" warning above exists to prevent. The override was created by setting `WorkspacePublicDnsName` and deploying (a since-removed opt-in), which built a `WorkspacePublicPrivateHostedZone`.

Detect it:

```bash
# From a workspace subnet host (or a classic cluster): the workspace URL must resolve
# to PUBLIC Databricks IPs, not 10.10.x
nslookup dbc-<deployment-id>.cloud.databricks.com
# There must be NO private hosted zone for the PUBLIC workspace name (only the two
# .privatelink zones are expected):
aws route53 list-hosted-zones --query "HostedZones[?Config.PrivateZone].name" --output table
```

Fix: remove the override so the workspace URL resolves publicly via NAT again (authorized by the workspace `default-policy` / `public_access_enabled = true`). If a CloudFormation stack created it (parameter `WorkspacePublicDnsName` set), clear that parameter and update the stack so CloudFormation deletes the `WorkspacePublicPrivateHostedZone`:

```bash
aws cloudformation update-stack \
  --stack-name <your-customer-vpc-stack> \
  --use-previous-template --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=WorkspacePublicDnsName,ParameterValue= \
               ParameterKey=ProjectName,UsePreviousValue=true
               # ...UsePreviousValue=true for every other stack parameter
```

If the zone was created outside CloudFormation, delete that hosted zone directly. Then restart the classic cluster / Pro warehouse and retry. `WorkspacePublicDnsName` is intentionally left **unwired** in this template so it can no longer create such an override.

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

The customer VPC template disables AWS private DNS on the SCC endpoint and uses dedicated private hosted zones (PR #31): `tunnel.privatelink` → SCC VPCE, workspace `dbc-*.privatelink` → REST VPCE. The **public** workspace hostname is not pinned; 8443–8451 go to Databricks over NAT. After the stack update, disassociate or delete leftover `cloud.databricks.com` apex PHZ `Z03487763H91UHKUM9J6C` and any leftover PHZ for `dbc-541c1fdc-07c5.cloud.databricks.com`, then restart the classic cluster. From a workspace subnet:

```bash
nslookup ncalifornia.privatelink.cloud.databricks.com   # REST VPCE ENIs
nslookup dbc-541c1fdc-07c5.privatelink.cloud.databricks.com
nslookup dbc-541c1fdc-07c5.cloud.databricks.com          # public IPs (not 10.10.1.x)
nslookup tunnel.privatelink.cloud.databricks.com         # SCC VPCE ENIs (not the REST pair)
nc -zv tunnel.privatelink.cloud.databricks.com 2443
nc -zv tunnel.privatelink.cloud.databricks.com 6666
nc -zv dbc-541c1fdc-07c5.cloud.databricks.com 8443
```

### Reference
Databricks documentation for creating a cross-account IAM role: [https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace?language=Databricks-managed%C2%A0VPC#step-1-create-a-cross-account-iam-role](https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace?language=Databricks-managed%C2%A0VPC#step-1-create-a-cross-account-iam-role)
