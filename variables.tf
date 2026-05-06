variable "source_policy_name" {
  description = "Display name of the existing DLP policy to replicate. Must match exactly one policy in the tenant."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.source_policy_name) >= 1 && length(var.source_policy_name) <= 256
    error_message = "source_policy_name must be between 1 and 256 characters."
  }
}

variable "output_file" {
  description = "Path to write the generated .tfvars file. Must end with .tfvars extension."
  type        = string
  default     = "replicated-dlp-policy.tfvars"
  nullable    = false

  validation {
    condition     = endswith(var.output_file, ".tfvars")
    error_message = "output_file must end with the .tfvars extension."
  }
}

variable "preserve_connector_rules" {
  description = "When true, preserves action_rules and endpoint_rules from the source policy's business connectors. When false (default), rules are stripped for simpler onboarding."
  type        = bool
  default     = false
  nullable    = false
}