data "powerplatform_data_loss_prevention_policies" "current" {}

data "powerplatform_connectors" "all" {}

resource "local_file" "generated_tfvars" {
  count = local.policy_exists ? 1 : 0

  content         = local.tfvars_content
  filename        = var.output_file
  file_permission = "0644"
}

# Batch mode: one file per found policy that has a corresponding output_files entry.
# Keyed by the original requested name (exact string) for stable state addresses.
# Missing and ambiguous policies produce no file.
resource "local_file" "generated_tfvars_batch" {
  for_each = {
    for name in coalesce(var.source_policy_names, []) :
    name => {
      content  = local._batch_tfvars_content[name]
      filename = var.output_files[name]
    }
    if contains(keys(local._batch_details), name) && contains(keys(var.output_files), name)
  }

  content         = each.value.content
  filename        = each.value.filename
  file_permission = "0644"
}

check "no_blockable_connectors_in_non_business" {
  assert {
    condition     = length(local.connectors_reclassified_to_blocked) == 0
    error_message = "${length(local.connectors_reclassified_to_blocked)} connector(s) in the source policy's NonBusiness group are blockable and will be reclassified to Blocked by res-dlppolicy. Review the 'connectors_reclassified_to_blocked' output before applying the generated tfvars. Affected connector IDs: ${jsonencode(local.connectors_reclassified_to_blocked)}"
  }
}

check "no_blockable_connectors_in_non_business_batch" {
  assert {
    condition     = length(local._batch_reclassified_connector_ids) == 0
    error_message = "${length(local._batch_reclassified_connector_ids)} unique connector ID(s) across all found batch policies appear in a NonBusiness group and are blockable — they will be reclassified to Blocked by res-dlppolicy. Review 'connectors_reclassified_to_blocked' inside each batch_results entry before applying the generated tfvars. Affected connector IDs: ${jsonencode(local._batch_reclassified_connector_ids)}"
  }
}
