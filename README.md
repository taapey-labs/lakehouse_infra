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

## Unity Catalog 403 (`Unauthorized network access to workspace` / `KCUC4`)

This exact body is **Databricks denying a network path into workspace `7474654246419237`**, not a missing GRANT. Checked against the four usual causes:

| Check | What this repo does | Verdict for KCUC4 |
|---|---|---|
| **1. UC / workspace network access (IP lists, perimeters, ingress policy)** | SRA attaches `{prefix}-np` with **cross-workspace `RESTRICTED_ACCESS`**. Allow-listing workspace `7474654246419237` as a *source* does not authorize the **Unity Catalog backend**. No workspace IP access list is created here. Public ingress stays `FULL_ACCESS` unless you set `context_based_ingress_ip_acl`. NAT EIP is stack output `NatPublicIp` if you must allow-list egress IPs elsewhere. | **This is the match.** Terraform now creates `{prefix}-uc-ingress-np` (cross-workspace **`FULL_ACCESS`**, private = all registered endpoints, public = full unless IP ACL) and rebinds workspace `7474654246419237` after SRA. |
| **2. Metastore / catalog workspace binding** | SRA assigns the regional metastore (`metastore_exists = true` reuses it) and creates an **ISOLATED** workspace catalog plus isolated storage credential / external location, auto-bound to this workspace. | Not this error string. Same-workspace use is bound. Cross-workspace table access would need `databricks_workspace_binding`, and would not say “Unauthorized network access”. |
| **3. Serverless NCC** | SRA always creates `{prefix}-ncc` and binds it. Default NCC has **no** extra private endpoint rules (`serverless_private_endpoint_rules`). Overlay policy sets serverless **egress `FULL_ACCESS`** so UC is not blocked by SRA’s empty restricted allow list (implicit UC allowlisting is deprecated). | Relevant for serverless SQL/warehouses; NCC mapping exists. Add PE rules only if serverless must reach private AWS services. |
| **4. Cloud storage firewall / S3 bucket policy** | Catalog bucket is created with public-access block and CMK; it is **not** limited to the VPC. Root workspace bucket gets SRA’s restrictive policy. | A storage 403 looks like S3 `AccessDenied`, not `KCUC4` / “Unauthorized network access to workspace”. |

Apply Terraform after merge. Account Console → Security → Networking should show workspace `7474654246419237` on `{resource_prefix}-uc-ingress-np`, not only `{resource_prefix}-np`. Then retry the UC command.

SRA will keep managing `{prefix}-np`; this overlay rebinds the workspace at the end of each apply. Do not re-attach `{prefix}-np` in the console.

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

## Additional catalog S3 bucket (existing instance profile)

Terraform creates a new bucket (`{resource_prefix}-data-{workspace_id}` by default), grants the **existing instance profile’s IAM role** access on that bucket, registers the profile in the workspace, and creates Unity Catalog objects:

- storage credential (the instance profile role)
- external location `s3://<bucket>/`
- catalog `lakehouse_data` (override with `additional_catalog_name`)
- `ALL_PRIVILEGES` for `admin_user`

Required variable:

```bash
terraform apply -var="catalog_instance_profile_arn=arn:aws:iam::<account>:instance-profile/<name>"
```

The instance profile role must trust Databricks Unity Catalog (`arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL`) with `sts:ExternalId` equal to the storage credential external ID (output `additional_catalog_uc_trust_external_id`). If that role is already a UC catalog role, trust is likely already present.

If `databricks_instance_profile` fails because the profile is already registered, import it:

```bash
terraform import databricks_instance_profile.catalog arn:aws:iam::<account>:instance-profile/<name>
```

