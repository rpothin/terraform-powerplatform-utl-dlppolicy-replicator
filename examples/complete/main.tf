module "dlp_replicator" {
  source  = "rpothin/utl-dlppolicy-replicator/powerplatform"

  source_policy_name       = var.source_policy_name
  output_file              = var.output_file
  preserve_connector_rules = var.preserve_connector_rules
}
