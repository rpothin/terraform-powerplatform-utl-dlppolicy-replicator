variable "source_policy_name" {
  description = "Display name of the DLP policy to replicate."
  type        = string
  default     = "My DLP Policy"
}

variable "output_file" {
  description = "Path to write the generated .tfvars file."
  type        = string
  default     = "replicated-dlp-policy.tfvars"
}

variable "preserve_connector_rules" {
  description = "When true, preserves action_rules and endpoint_rules from the source policy."
  type        = bool
  default     = false
}