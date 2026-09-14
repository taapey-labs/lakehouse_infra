# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/account_network_policy
# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_network_option

# NOTE: If this resource fails, verify that network_policy_id is no more than 32 characters.
# If using the Security Analysis Tool, please allow list PyPI.org to ensure functionality.

resource "databricks_account_network_policy" "restrictive_network_policy" {
  account_id        = var.databricks_account_id
  network_policy_id = "${var.resource_prefix}-np" # Must not be more than 32 characters.

  # This account rejects ingress.cross_workspace_access. Do not send that field.
  # Sending public_access-only ingress still default-denies Unity Catalog
  # (403 Unauthorized network access to workspace / KCUC4). Omit ingress so
  # Databricks keeps Compatibility-mode defaults. Attach default-policy to the
  # workspace; do not attach this object unless UC is confirmed allowed.
  egress = {
    network_access = {
      restriction_mode = "FULL_ACCESS"
      policy_enforcement = {
        enforcement_mode = "ENFORCED"
      }
    }
  }

  ingress = length(var.context_based_ingress_ip_acl) > 0 ? {
    public_access = {
      restriction_mode = "RESTRICTED_ACCESS"
      allow_rules = [
        {
          label = "${var.resource_prefix}-ingress-allow"
          origin = {
            included_ip_ranges = {
              ip_ranges = var.context_based_ingress_ip_acl
            }
          }
        }
      ]
    }
  } : null
}
