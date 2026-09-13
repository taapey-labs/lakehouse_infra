# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/account_network_policy
# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_network_option

# NOTE: If this resource fails, verify that network_policy_id is no more than 32 characters.
# If using the Security Analysis Tool, please allow list PyPI.org to ensure functionality.

resource "databricks_account_network_policy" "restrictive_network_policy" {
  account_id        = var.databricks_account_id
  network_policy_id = "${var.resource_prefix}-np" # Must not be more than 32 characters.

  # This custom policy is kept for optional later use. Do not attach it to the
  # workspace: this account cannot set ingress.cross_workspace_access, so the
  # API default denies Unity Catalog with 403 Unauthorized network access
  # (KCUC4). The workspace binds default-policy instead.
  egress = {
    network_access = {
      restriction_mode = "FULL_ACCESS"
      policy_enforcement = {
        enforcement_mode = "ENFORCED"
      }
    }
  }

  ingress = {
    public_access = {
      restriction_mode = length(var.context_based_ingress_ip_acl) > 0 ? "RESTRICTED_ACCESS" : "FULL_ACCESS"
      allow_rules = length(var.context_based_ingress_ip_acl) > 0 ? [
        {
          label = "${var.resource_prefix}-ingress-allow"
          origin = {
            included_ip_ranges = {
              ip_ranges = var.context_based_ingress_ip_acl
            }
          }
        }
      ] : []
    }
  }
}
