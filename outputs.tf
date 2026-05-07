output "display_name" {
  description = "Display name of the source DLP policy."
  value       = local.policy_exists ? local.selected_policy.display_name : null
}

output "environment_type" {
  description = "Environment scope type of the source DLP policy (AllEnvironments, ExceptEnvironments, or OnlyEnvironments)."
  value       = local.policy_exists ? local.selected_policy.environment_type : null
}

output "environments" {
  description = "Normalised (lowercase, sorted) list of environment IDs scoped to the source DLP policy."
  value       = local.environments_normalised
}

output "default_connectors_classification" {
  description = "Default classification for connectors not explicitly listed (Business or NonBusiness)."
  value       = local.policy_exists ? local.selected_policy.default_connectors_classification : null
}

output "business_connectors" {
  description = "List of business connectors from the source policy, ready for use with res-dlppolicy."
  value       = local.business_connectors
}

output "custom_connectors_patterns" {
  description = "Custom connector URL patterns from the source policy (wildcard pattern excluded)."
  value       = local.custom_connectors_patterns
}

output "policy_found" {
  description = "Whether a DLP policy with the given display_name was found in the tenant."
  value       = local.policy_exists
}

output "tfvars_file_path" {
  description = "Path of the generated .tfvars file, or null if the policy was not found."
  value       = try(local_file.generated_tfvars[0].filename, null)
}

output "generated_tfvars_content" {
  description = "The full content of the generated .tfvars file, or empty string if the policy was not found. This output changes on every plan because it embeds a generation timestamp — intentional for a one-shot migration utility."
  value       = local.tfvars_content
}

output "connectors_reclassified_to_blocked" {
  description = "IDs of connectors that are in the source policy's NonBusiness group but are blockable. These will be reclassified to Blocked by res-dlppolicy post-migration."
  value       = local.connectors_reclassified_to_blocked
}

output "migration_summary" {
  description = "Summary object with policy metadata, connector counts, behavioural flags, and generation timestamp. The 'generation_timestamp' field uses timestamp() and changes on every plan — intentional for a one-shot migration utility."
  value = {
    source_policy_name             = var.source_policy_name
    policy_found                   = local.policy_exists
    display_name                   = local.policy_exists ? local.selected_policy.display_name : null
    business_connector_count       = length(local.business_connectors)
    custom_connector_pattern_count = length(local.custom_connectors_patterns)
    environment_count              = length(local.environments_normalised)
    reclassified_connector_count   = length(local.connectors_reclassified_to_blocked)
    preserve_connector_rules       = var.preserve_connector_rules
    generation_timestamp           = timestamp()
  }
}
