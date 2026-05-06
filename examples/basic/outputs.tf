output "policy_found" {
  description = "Whether the DLP policy was found in the tenant."
  value       = module.dlp_replicator.policy_found
}

output "tfvars_file_path" {
  description = "Path of the generated .tfvars file."
  value       = module.dlp_replicator.tfvars_file_path
}

output "connectors_reclassified_to_blocked" {
  description = "Connector IDs that will be reclassified to Blocked after migration."
  value       = module.dlp_replicator.connectors_reclassified_to_blocked
}