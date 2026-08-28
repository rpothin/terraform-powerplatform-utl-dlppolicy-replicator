variable "source_policy_names" {
  description = "List of DLP policy display names to replicate in batch mode."
  type        = list(string)
  default     = ["My DLP Policy", "My Second DLP Policy"]
}

variable "output_files" {
  description = "Map of policy display names to output .tfvars file paths."
  type        = map(string)
  default = {
    "My DLP Policy"        = "my-dlp-policy.tfvars"
    "My Second DLP Policy" = "my-second-dlp-policy.tfvars"
  }
}

variable "preserve_connector_rules" {
  description = "When true, preserves action_rules and endpoint_rules from the source policy."
  type        = bool
  default     = false
}
