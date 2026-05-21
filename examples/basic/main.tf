module "dlp_replicator" {
  source  = "rpothin/utl-dlppolicy-replicator/powerplatform"
  version = "~> 0.1"

  source_policy_name = var.source_policy_name
}
