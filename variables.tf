variable "source_policy_name" {
  description = "Display name of the existing DLP policy to replicate (scalar mode). Exactly one of source_policy_name or source_policy_names must be set. Must match exactly one policy in the tenant. Must be between 1 and 256 non-blank characters when set."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.source_policy_name == null || (length(var.source_policy_name) >= 1 && length(var.source_policy_name) <= 256)
    error_message = "source_policy_name must be between 1 and 256 characters."
  }

  validation {
    condition     = var.source_policy_name == null || trimspace(var.source_policy_name) != ""
    error_message = "source_policy_name must not be blank or whitespace-only."
  }
}

variable "source_policy_names" {
  description = "List of DLP policy display names to extract in one batch invocation (batch mode). Exactly one of source_policy_name or source_policy_names must be set. Each name must be unique within the list, non-blank, and between 1 and 256 characters. Duplicate names are rejected to prevent silent key collisions."
  type        = list(string)
  default     = null
  nullable    = true

  validation {
    condition     = !(var.source_policy_name != null && var.source_policy_names != null)
    error_message = "Only one of source_policy_name or source_policy_names may be set at a time. Remove one of them."
  }

  validation {
    condition     = var.source_policy_name != null || var.source_policy_names != null
    error_message = "Exactly one of source_policy_name or source_policy_names must be set. Provide one of them."
  }

  validation {
    condition     = var.source_policy_names == null || length(var.source_policy_names) >= 1
    error_message = "source_policy_names must contain at least one entry when set."
  }

  validation {
    condition     = var.source_policy_names == null || alltrue([for n in var.source_policy_names : trimspace(n) != ""])
    error_message = "source_policy_names must not contain blank or whitespace-only entries."
  }

  validation {
    condition     = var.source_policy_names == null || alltrue([for n in var.source_policy_names : length(n) >= 1 && length(n) <= 256])
    error_message = "Each entry in source_policy_names must be between 1 and 256 characters."
  }

  validation {
    condition     = var.source_policy_names == null || length(var.source_policy_names) == length(toset(var.source_policy_names))
    error_message = "source_policy_names must not contain duplicate entries. Duplicate names would create key collisions in batch outputs."
  }
}

variable "output_file" {
  description = "Path to write the generated .tfvars file in scalar mode (relative to the Terraform working directory). Must end with .tfvars extension. Unused in batch mode — use output_files instead."
  type        = string
  default     = "replicated-dlp-policy.tfvars"
  nullable    = false

  validation {
    condition     = endswith(var.output_file, ".tfvars")
    error_message = "output_file must end with the .tfvars extension."
  }
}

variable "output_files" {
  description = "Map of policy display names to output file paths for batch mode. Keys must match entries in source_policy_names. All values must end with .tfvars. Only found policies with a matching key will have a file written. Missing and ambiguous policies never produce a file. Must be empty in scalar mode."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for path in values(var.output_files) : endswith(path, ".tfvars")])
    error_message = "All paths in output_files must end with the .tfvars extension."
  }

  validation {
    condition     = var.source_policy_names != null || length(var.output_files) == 0
    error_message = "output_files must be empty when using scalar mode (source_policy_name). Use output_file for scalar destinations."
  }

  validation {
    condition     = var.source_policy_names == null || alltrue([for k in keys(var.output_files) : contains(var.source_policy_names, k)])
    error_message = "All keys in output_files must correspond to entries in source_policy_names."
  }
}

variable "preserve_connector_rules" {
  description = "When true, preserves action_rules and endpoint_rules from the source policy's business connectors. When false (default), rules are stripped for simpler onboarding. Applies to both scalar and batch modes."
  type        = bool
  default     = false
  nullable    = false
}
