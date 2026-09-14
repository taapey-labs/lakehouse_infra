# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/account_network_policy
# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_network_option

# NOTE: If this resource fails, verify that network_policy_id is no more than 32 characters.
# If using the Security Analysis Tool, please allow list PyPI.org to ensure functionality.

locals {
  cross_workspace_restricted = var.cross_workspace_ingress_restriction_mode == "RESTRICTED_ACCESS"
}

resource "databricks_account_network_policy" "restrictive_network_policy" {
  account_id        = var.databricks_account_id
  network_policy_id = "${var.resource_prefix}-np" # Must not be more than 32 characters.

  # Serverless egress FULL_ACCESS so UC and control-plane calls are not
  # blocked by an empty destination allow list.
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

    # Unity Catalog's backend is a Databricks-managed source workspace, not this
    # workspace ID. Omitting cross_workspace_access (or RESTRICTED_ACCESS with
    # only this workspace allow-listed) returns:
    #   HTTP 403 Unauthorized network access to workspace  (SQLSTATE KCUC4)
    # FULL_ACCESS allows any serverless source, including UC.
    # LEGACY_MODE is account-console "Compatibility mode" (stock default-policy).
    # RESTRICTED_ACCESS uses all_source_workspaces so UC is still allowed.
    cross_workspace_access = {
      restriction_mode = var.cross_workspace_ingress_restriction_mode
      allow_rules = local.cross_workspace_restricted ? [
        {
          label = "${var.resource_prefix}-uc-cross-workspace"
          origin = {
            all_source_workspaces = true
          }
          destination = {
            all_destinations = true
          }
        }
      ] : []
    }
  }
}
