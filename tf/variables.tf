variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/23"
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
  description = "Egress ports for the security group"
  default     = [53, 443, 80, 22, 3306, 1433, 1521,]
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
  description = "Workspace PrivateLink VPC endpoint ID from the vpc_customer.manage.template stack output DatabricksWorkspaceVpcEndpointId"
}

variable "custom_scc_relay_vpce_id" {
  type        = string
  description = "SCC relay PrivateLink VPC endpoint ID from the vpc_customer.manage.template stack output DatabricksSccRelayVpcEndpointId"
}

# Set when the AWS VPC endpoints above are already registered with the Databricks account (skips re-registration)
variable "custom_general_access_mws_vpce_id" {
  type        = string
  default     = null
  description = "Pre-registered Databricks MWS VPC endpoint ID for General Access (accounts.../vpc-endpoints)"
}

variable "custom_scc_relay_mws_vpce_id" {
  type        = string
  default     = null
  description = "Pre-registered Databricks MWS VPC endpoint ID for the SCC relay (accounts.../vpc-endpoints)"
}
