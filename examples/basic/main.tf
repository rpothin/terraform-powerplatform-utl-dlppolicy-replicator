module "dlp_replicator" {
  # TODO: Replace with Terraform Registry address before publishing, e.g.:
  # source  = "rpothin/utl-dlppolicy-replicator/powerplatform"
  # version = "~> X.Y"
  source = "../../"

  source_policy_name = var.source_policy_name
}
