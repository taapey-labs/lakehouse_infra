# Unity Catalog KCUC4: "Unauthorized network access to workspace".
# SRA attaches {resource_prefix}-np with cross-workspace RESTRICTED_ACCESS. Allow-listing
# this workspace as a *source* does not authorize the Unity Catalog control plane, so UC
# API calls from classic/serverless still 403. This policy restores compatibility-mode
# cross-workspace ingress and full serverless egress, then re-binds the workspace.
# Applied after module.databricks_sra so it wins at the end of each apply.

resource "databricks_account_network_policy" "unity_catalog_access" {
  provider          = databricks.accounts
  account_id        = var.databricks_account_id
  network_policy_id = "${var.resource_prefix}-uc-ingress-np"

  egress = {
    network_access = {
      restriction_mode = "FULL_ACCESS"
      policy_enforcement = {
        enforcement_mode = "ENFORCED"
      }
    }
  }

  ingress = {
    # FULL_ACCESS: Unity Catalog backend calls are treated as cross-workspace ingress.
    # SRA's RESTRICTED_ACCESS + this workspace ID as source is not enough (KCUC4).
    # Provider ~> 1.121 supports FULL_ACCESS / RESTRICTED_ACCESS (not LEGACY_MODE).
    cross_workspace_access = {
      restriction_mode = "FULL_ACCESS"
    }
    private_access = {
      restriction_mode = "ALLOW_ALL_REGISTERED_ENDPOINTS"
    }
    public_access = {
      restriction_mode = length(var.context_based_ingress_ip_acl) > 0 ? "RESTRICTED_ACCESS" : "FULL_ACCESS"
      allow_rules = length(var.context_based_ingress_ip_acl) > 0 ? [
        {
          label = "${var.resource_prefix}-uc-ingress-allow"
          origin = {
            included_ip_ranges = {
              ip_ranges = var.context_based_ingress_ip_acl
            }
          }
        }
      ] : []
    }
  }

  depends_on = [module.databricks_sra]
}

resource "databricks_workspace_network_option" "unity_catalog_access" {
  provider          = databricks.accounts
  workspace_id      = var.workspace_id
  network_policy_id = databricks_account_network_policy.unity_catalog_access.network_policy_id
  depends_on        = [module.databricks_sra, databricks_account_network_policy.unity_catalog_access]
}