variable "resource_prefix" {
  description = "Prefix for resource tags."
  type        = string
}

variable "enable_compliance_security_profile" {
  description = "When true, use the Nitro node type (m5n.large) required on CSP workspaces. Otherwise m5.large, matching the Databricks Git Proxy enablement notebook."
  type        = bool
  default     = false
}

variable "spark_env_vars" {
  description = "Optional Git Proxy environment variables (GIT_PROXY_ENABLE_SSL_VERIFICATION, GIT_PROXY_CA_CERT_PATH, GIT_PROXY_HTTP_PROXY, GIT_PROXY_CUSTOM_HTTP_PORT)."
  type        = map(string)
  default     = {}
}
