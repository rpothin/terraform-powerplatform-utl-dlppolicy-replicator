output "policy_found" {
  description = "Whether the DLP policy was found in the tenant."
  value       = module.dlp_replicator.policy_found
}

output "tfvars_file_path" {
  description = "Path of the generated .tfvars file."
  value       = module.dlp_replicator.tfvars_file_path
}

output "generated_tfvars_content" {
  description = "Full content of the generated .tfvars file."
  value       = module.dlp_replicator.generated_tfvars_content
}

output "connectors_reclassified_to_blocked" {
  description = "Connector IDs that will be reclassified to Blocked after migration."
  value       = module.dlp_replicator.connectors_reclassified_to_blocked
}

output "migration_summary" {
  description = "Summary of the migration including counts and flags."
  value       = module.dlp_replicator.migration_summary
}