data "powerplatform_data_loss_prevention_policies" "current" {}

data "powerplatform_connectors" "all" {}

resource "local_file" "generated_tfvars" {
  count = local.policy_exists ? 1 : 0

  content         = local.tfvars_content
  filename        = var.output_file
  file_permission = "0644"
}

check "no_blockable_connectors_in_non_business" {
  assert {
    condition     = length(local.connectors_reclassified_to_blocked) == 0
    error_message = "${length(local.connectors_reclassified_to_blocked)} connector(s) in the source policy's NonBusiness group are blockable and will be reclassified to Blocked by res-dlppolicy. Review the 'connectors_reclassified_to_blocked' output before applying the generated tfvars. Affected connector IDs: ${jsonencode(local.connectors_reclassified_to_blocked)}"
  }
}
