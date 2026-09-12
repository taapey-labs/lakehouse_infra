variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "network_configuration" {
  type        = string
  description = "Network configuration mode for the SRA module (e.g., 'custom')"
}

variable "account_console" {
  type        = string
  description = "URL for the AWS account console"
  default     = "https://accounts.cloud.databricks.com"
}


variable "compute_mode" {
  type        = string
  description = "Compute mode for the SRA module (e.g., 'HYBRID')"
}
variable "vpc_cidr" {
  type        = string
  default     = "10.10.0.0/18"
  description = "Documentation-only CIDR matching vpc_customer.manage.template VpcCidr (SRA custom VPC is created in CloudFormation, not Terraform)"
}

variable "databricks_account_id" {
  type        = string
  description = "Your global Databricks Account ID (from ://databricks.com)"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID where the SRA workspace resources are deployed"
  sensitive   = true
}

variable "databricks_client_id" {
  type        = string
  description = "Databricks account service principal client ID, passed through to the SRA module's created_workspace provider"
  sensitive   = true
}

variable "databricks_client_secret" {
  type        = string
  description = "Databricks account service principal client secret, passed through to the SRA module's created_workspace provider"
  sensitive   = true
}

variable "resource_prefix" {
  type        = string
  default     = "lakehouse"
  description = "Prefix used by the SRA module for naming/tagging resources (1-26 chars, a-z0-9-)"
}

variable "admin_user" {
  type        = string
  description = "Email of the admin user for the workspace and workspace catalog"
}

variable "metastore_exists" {
  type        = bool
  default     = true
  description = "Whether a Unity Catalog metastore already exists for this region"
}

variable "audit_log_delivery_exists" {
  type        = bool
  default     = true
  description = "Set true when the Databricks account already has an audit log delivery configuration (MWS credential name {prefix}-audit-log-delivery-credential). SRA skips creating it when true."
}

variable "custom_default_catalog" {
  type        = string
  description = "Custom default Unity Catalog for the workspace"
}
# --- Custom network configuration: sourced from the vpc_customer.manage.template CloudFormation stack outputs ---
variable "custom_vpc_id" {
  type        = string
  description = "VPC ID from the vpc_customer.manage.template stack output VpcId"
}
variable "sg_egress_ports" {
  type        = list(number)
  description = "Egress ports for the security group (must include SCC relay 6666 and FIPS/ngrok 2443)"
  default     = [53, 80, 22, 443, 2443, 3306, 1433, 1521, 6666, 8443, 8444, 8445, 8446, 8447, 8448, 8449, 8450, 8451]
}

variable "custom_private_subnet_ids" {
  type        = list(string)
  description = "Workspace subnet IDs from the vpc_customer.manage.template stack outputs WorkspaceSubnetAId/WorkspaceSubnetBId"
}

variable "custom_sg_id" {
  type        = string
  description = "Security group ID from the vpc_customer.manage.template stack output DatabricksSecurityGroupId"
}

variable "custom_general_access_vpce_id" {
  type        = string
  description = "AWS vpce- id from CloudFormation DatabricksWorkspaceVpcEndpointId (REST). Do not pass a Databricks account (MWS) VPC endpoint UUID."
}

variable "custom_scc_relay_vpce_id" {
  type        = string
  description = "AWS vpce- id from CloudFormation DatabricksSccRelayVpcEndpointId (SCC). Do not pass a Databricks account (MWS) VPC endpoint UUID."
}

# SRA defaults this to [] (RESTRICTED_ACCESS, no sources). Unity Catalog backend
# calls into the workspace are then denied with:
#   403 Unauthorized network access to workspace: <id>  (SQLSTATE KCUC4)
# Allow-listing this workspace as a source unblocks same-workspace UC/serverless.
variable "cross_workspace_ingress_allowed_workspace_ids" {
  type        = list(number)
  description = "Source workspace IDs allowed to reach this workspace over SRA cross-workspace ingress"
  default     = [7474654246419237]
}

variable "workspace_id" {
  type        = number
  description = "Numeric Databricks workspace ID (7474654246419237). Used to name the additional catalog bucket and default credential/role."
  default     = 7474654246419237
}

# Option 1: public/context-based ingress IP allow list. Empty = SRA public_access FULL_ACCESS.
# Set to NAT EIP/CIDRs only if you have already enabled IP restriction on the workspace or metastore.
variable "context_based_ingress_ip_acl" {
  type        = list(string)
  description = "Optional public IPv4 CIDRs allowed to reach the workspace (SRA context-based ingress)"
  default     = []
}

# Option 3: extra NCC private endpoint rules for serverless (S3, RDS, etc.).
variable "serverless_private_endpoint_rules" {
  type        = any
  description = "Optional list of Databricks NCC private endpoint rules passed to SRA"
  default     = []
}

variable "existing_storage_credential_name" {
  type        = string
  description = "Existing Unity Catalog storage credential used for the additional catalog bucket. Defaults to the SRA workspace catalog credential ({resource_prefix}-catalog-{workspace_id}-storage-credential)"
  default     = null
}

variable "existing_storage_credential_role_name" {
  type        = string
  description = "IAM role name used by that storage credential. Defaults to the SRA catalog role ({resource_prefix}-catalog-{workspace_id})"
  default     = null
}

variable "additional_catalog_name" {
  type        = string
  description = "Unity Catalog name for the additional catalog backed by the new S3 bucket"
  default     = "lakehouse_data"
}

variable "additional_catalog_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for the additional catalog. Defaults to {resource_prefix}-data-{workspace_id}"
  default     = null
}

variable "sql_warehouse_name" {
  type        = string
  default     = "Starter Warehouse"
  description = "SQL warehouse name. Set to Starter Warehouse to manage the workspace default warehouse."
}

variable "sql_warehouse_cluster_size" {
  type        = string
  default     = "2X-Small"
  description = "Starter SQL warehouse size. Databricks values: 2X-Small, X-Small, Small, Medium, Large, X-Large, 2X-Large, 3X-Large, 4X-Large."
}

variable "sql_warehouse_auto_stop_mins" {
  type        = number
  default     = 10
  description = "Minutes of inactivity before the starter SQL warehouse stops."
}
