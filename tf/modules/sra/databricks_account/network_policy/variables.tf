variable "context_based_ingress_ip_acl" {
  description = "Optional list of IP addresses/CIDRs used to limit access to the workspace based on IPs. Added to the network policy as ingress rules. Leave empty to apply no IP-based ingress restriction."
  type        = list(string)
  default     = []
}

variable "cross_workspace_ingress_allowed_workspace_ids" {
  description = "Unused. Allow-listing only this workspace ID does not permit Unity Catalog (UC is a different source workspace). Cross-workspace ingress is FULL_ACCESS unless overridden."
  type        = list(number)
  default     = []
}

variable "cross_workspace_ingress_restriction_mode" {
  description = "ingress.cross_workspace_access.restriction_mode. FULL_ACCESS allows Unity Catalog; LEGACY_MODE is Compatibility mode; RESTRICTED_ACCESS still allows all source workspaces so UC is not 403 KCUC4."
  type        = string
  default     = "FULL_ACCESS"

  validation {
    condition     = contains(["FULL_ACCESS", "LEGACY_MODE", "RESTRICTED_ACCESS"], var.cross_workspace_ingress_restriction_mode)
    error_message = "cross_workspace_ingress_restriction_mode must be FULL_ACCESS, LEGACY_MODE, or RESTRICTED_ACCESS."
  }
}

variable "databricks_account_id" {
  description = "ID of the Databricks account."
  type        = string
}

variable "enable_security_analysis_tool" {
  description = "Flag to enable the security analysis tool. When true, PyPI is added to the egress allow list so SAT can install its dependencies."
  type        = bool
  default     = false
}

variable "region" {
  description = "AWS region code."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for the resource names."
  type        = string
}
