# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/account_network_policy
# Terraform Documentation: https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/workspace_network_option

# Do not create {prefix}-np (sss-aws-lakehouse-np). This account cannot set
# ingress.cross_workspace_access, so that policy 403s Unity Catalog (KCUC4).
# count = 0 destroys the existing object after the workspace uses default-policy.
# If delete fails because the workspace is still attached, apply again after
# databricks_workspace_network_option has switched to default-policy.
resource "databricks_account_network_policy" "restrictive_network_policy" {
  count = 0

  account_id        = var.databricks_account_id
  network_policy_id = "${var.resource_prefix}-np"
}
