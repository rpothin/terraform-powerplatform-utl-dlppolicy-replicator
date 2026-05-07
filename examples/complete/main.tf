module "dlp_replicator" {
  # TODO: Replace with Terraform Registry address before publishing, e.g.:
  # source  = "rpothin/dlppolicy-replicator/powerplatform//modules/utl-dlppolicy-replicator"
  # version = "~> X.Y"
  source = "../../"

  source_policy_name       = var.source_policy_name
  output_file              = var.output_file
  preserve_connector_rules = var.preserve_connector_rules
}
