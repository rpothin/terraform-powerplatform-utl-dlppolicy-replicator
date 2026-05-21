module "dlp_replicator" {
  source = "rpothin/utl-dlppolicy-replicator/powerplatform"

  source_policy_name = var.source_policy_name
}
