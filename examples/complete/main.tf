module "dlp_replicator" {
  source = "rpothin/utl-dlppolicy-replicator/powerplatform"

  source_policy_names      = var.source_policy_names
  output_files             = var.output_files
  preserve_connector_rules = var.preserve_connector_rules
}
