output "batch_results" {
  description = "Map of policy names to their extraction results."
  value       = module.dlp_replicator.batch_results
}

output "batch_file_paths" {
  description = "Map of policy names to written .tfvars file paths."
  value       = module.dlp_replicator.batch_file_paths
}

