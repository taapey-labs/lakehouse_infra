# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/account_network_policy
# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_network_option

# NOTE: If this resource fails, verify that network_policy_id is no more than 32 characters.
# If using the Security Analysis Tool, please allow list PyPI.org to ensure functionality.

resource "databricks_account_network_policy" "restrictive_network_policy" {
  account_id        = var.databricks_account_id
  network_policy_id = "${var.resource_prefix}-np" # Must not be more than 32 characters.

  # RESTRICTED_ACCESS with an empty allow list blocks Unity Catalog backend
  # calls into the workspace (HTTP 403 Unauthorized network access to workspace).
  # This account cannot set ingress.cross_workspace_access, so open serverless
  # egress instead (same as the previous {prefix}-uc-ingress-np overlay).
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
