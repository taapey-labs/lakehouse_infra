# Pinned to a commit since the SRA repo publishes no tagged releases; bump deliberately.
# The module declares its own aws/databricks provider configs (auth via standard AWS
# credential chain + DATABRICKS_CLIENT_ID/DATABRICKS_CLIENT_SECRET env vars), so no
# `providers = {}` passthrough is possible here.
module "databricks_sra" {
  source = "github.com/databricks/terraform-databricks-sra/aws/tf?ref=42ccfa089ea142ed50c324b7a0cc9e2189c4774d"

  compute_mode          = "HYBRID"
  network_configuration = "custom"
  region                = var.aws_region
  resource_prefix       = var.resource_prefix
  admin_user            = var.admin_user
  databricks_account_id = var.databricks_account_id
  aws_account_id        = var.aws_account_id
  metastore_exists      = var.metastore_exists
  compliance_standards  = []
  # default_catalog   = var.custom_default_catalog

  custom_vpc_id                 = var.custom_vpc_id
  custom_private_subnet_ids     = var.custom_private_subnet_ids
  custom_sg_id                  = var.custom_sg_id
  custom_general_access_vpce_id = var.custom_general_access_vpce_id
  custom_scc_relay_vpce_id      = var.custom_scc_relay_vpce_id
  sg_egress_ports = var.sg_egress_ports
  custom_general_access_mws_vpce_id = var.custom_general_access_mws_vpce_id
  custom_scc_relay_mws_vpce_id      = var.custom_scc_relay_mws_vpce_id

  databricks_client_id     = var.databricks_client_id
  databricks_client_secret = var.databricks_client_secret

  cross_workspace_ingress_allowed_workspace_ids = var.cross_workspace_ingress_allowed_workspace_ids
  context_based_ingress_ip_acl                  = var.context_based_ingress_ip_acl
  serverless_private_endpoint_rules             = var.serverless_private_endpoint_rules
}
