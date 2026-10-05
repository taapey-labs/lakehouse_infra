# Git server proxy for Databricks Git folders (Repos).
# Matches https://github.com/databricks/databricks-repos-proxy/blob/main/enable_git_proxy_jupyter.ipynb
# Do not change spark_version; the proxy image is tied to this DBR.

resource "databricks_cluster" "this" {
  cluster_name            = "Repos Git Proxy"
  spark_version           = "16.4.x-scala2.13"
  node_type_id            = var.enable_compliance_security_profile ? "m5n.large" : "m5.large"
  data_security_mode      = "USER_ISOLATION"
  autotermination_minutes = 0
  num_workers             = 0
  is_single_node          = true
  is_pinned               = true

  spark_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*]"
  }

  custom_tags = {
    ResourceClass = "SingleNode"
    SRA           = var.resource_prefix
  }

  aws_attributes {
    first_on_demand  = 1
    ebs_volume_count = 1
    ebs_volume_size  = 32
  }

  spark_env_vars = length(var.spark_env_vars) > 0 ? var.spark_env_vars : null
}

# Workspace-conf is one resource per workspace. This module is the only
# databricks_workspace_conf in SRA; do not add a second copy.
resource "databricks_workspace_conf" "this" {
  custom_config = {
    enableGitProxy    = "true"
    gitProxyClusterId = databricks_cluster.this.id
  }
}

# Docs: remove CAN ATTACH TO for all workspace users so they cannot run
# arbitrary workloads on the always-on proxy cluster.
resource "databricks_permissions" "this" {
  cluster_id = databricks_cluster.this.id

  access_control {
    group_name       = "admins"
    permission_level = "CAN_MANAGE"
  }
}
