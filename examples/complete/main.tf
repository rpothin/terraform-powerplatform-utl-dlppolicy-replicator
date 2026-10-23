module "dlp_replicator" {
  source = "rpothin/utl-dlppolicy-replicator/powerplatform"

  source_policy_names      = var.source_policy_names
  output_files             = var.output_files
  preserve_connector_rules = var.preserve_connector_rules
  bapi_host                = var.bapi_host
  bapi_scope               = var.bapi_scope
}
