module "aws_databricks_sra" {
  # source = "github.com/databricks/terraform-databricks-sra/aws/tf?ref=42ccfa089ea142ed50c324b7a0cc9e2189c4774d"

  source = "./modules/sra"

  # deployment_name = var.deployment_name
  compute_mode          = var.compute_mode
  network_configuration = var.network_configuration
  region                = var.aws_region
  resource_prefix       = var.resource_prefix
  admin_user            = var.admin_user
  databricks_account_id = var.databricks_account_id
  aws_account_id        = var.aws_account_id
  metastore_exists           = var.metastore_exists
  audit_log_delivery_exists  = var.audit_log_delivery_exists
  compliance_standards       = []
  # default_catalog   = var.custom_default_catalog

  custom_vpc_id                 = var.custom_vpc_id
  custom_private_subnet_ids     = var.custom_private_subnet_ids
  custom_sg_id                  = var.custom_sg_id
  sg_egress_ports               = var.sg_egress_ports
  custom_general_access_vpce_id = var.custom_general_access_vpce_id
  custom_scc_relay_vpce_id      = var.custom_scc_relay_vpce_id
  context_based_ingress_ip_acl                  = var.context_based_ingress_ip_acl
  serverless_private_endpoint_rules             = var.serverless_private_endpoint_rules

  sql_warehouse_name           = var.sql_warehouse_name
  sql_warehouse_cluster_size   = var.sql_warehouse_cluster_size
  sql_warehouse_auto_stop_mins = var.sql_warehouse_auto_stop_mins

  metastore_bucket_name = var.metastore_bucket_name
}
