data "powerplatform_rest_query" "policies_list" {
  method               = "GET"
  url                  = "https://${var.bapi_host}/providers/PowerPlatform.Governance/v2/policies"
  scope                = var.bapi_scope
  expected_http_status = [200]

  lifecycle {
    postcondition {
      condition = try(
        (
          try(jsondecode(self.output.body).nextLink == null, true) ||
          try(trimspace(jsondecode(self.output.body).nextLink) == "", false)
        ) &&
        (
          try(jsondecode(self.output.body)["@odata.nextLink"] == null, true) ||
          try(trimspace(jsondecode(self.output.body)["@odata.nextLink"]) == "", false)
        ) &&
        can(tolist(jsondecode(self.output.body).value)) &&
        alltrue([
          for policy in tolist(jsondecode(self.output.body).value) :
          try(
            trimspace(policy.policyDefinition.name) != "" &&
            trimspace(policy.policyDefinition.displayName) != "",
            false
          )
        ]),
        false
      )
      error_message = "The DLP policy list response is malformed or paginated. The module requires one complete page with a name and displayName for every policy."
    }

    postcondition {
      condition = var.source_policy_name == null ? true : try(
        length([
          for policy in tolist(jsondecode(self.output.body).value) :
          policy if policy.policyDefinition.displayName == var.source_policy_name
        ]) <= 1,
        false
      )
      error_message = "The scalar source_policy_name matches multiple DLP policies. Use batch mode to receive an ambiguous status."
    }
  }
}

data "powerplatform_rest_query" "policy" {
  for_each = local._found_policy_ids

  method               = "GET"
  url                  = "https://${var.bapi_host}/providers/PowerPlatform.Governance/v2/policies/${urlencode(each.value)}"
  scope                = var.bapi_scope
  expected_http_status = [200]

  lifecycle {
    postcondition {
      condition = try(
        jsondecode(self.output.body).policyDefinition.name == each.value &&
        jsondecode(self.output.body).policyDefinition.displayName == each.key &&
        contains(["General", "Confidential", "Blocked"], jsondecode(self.output.body).policyDefinition.defaultConnectorsClassification) &&
        contains(["AllEnvironments", "ExceptEnvironments", "OnlyEnvironments"], jsondecode(self.output.body).policyDefinition.environmentType) &&
        can(tolist(coalesce(try(jsondecode(self.output.body).policyDefinition.environments, null), []))) &&
        alltrue([
          for environment in tolist(coalesce(try(jsondecode(self.output.body).policyDefinition.environments, null), [])) :
          try(trimspace(environment.name) != "", false)
        ]) &&
        contains(keys(jsondecode(self.output.body).policyDefinition), "connectorGroups") &&
        can(tolist(coalesce(jsondecode(self.output.body).policyDefinition.connectorGroups, []))) &&
        length(distinct([
          for group in tolist(coalesce(jsondecode(self.output.body).policyDefinition.connectorGroups, [])) :
          group.classification
        ])) == length(tolist(coalesce(jsondecode(self.output.body).policyDefinition.connectorGroups, []))) &&
        alltrue([
          for group in tolist(coalesce(jsondecode(self.output.body).policyDefinition.connectorGroups, [])) :
          try(
            contains(["Confidential", "General", "Blocked"], group.classification) &&
            can(tolist(coalesce(try(group.connectors, null), []))) &&
            alltrue([
              for connector in tolist(coalesce(try(group.connectors, null), [])) :
              trimspace(connector.id) != ""
            ]),
            false
          )
        ]) &&
        (
          try(jsondecode(self.output.body).connectorConfigurationsDefinition == null, true) ||
          try(
            alltrue([
              for config in coalesce(try(jsondecode(self.output.body).connectorConfigurationsDefinition.connectorActionConfigurations, null), []) :
              try(
                trimspace(config.connectorId) != "" &&
                contains(
                  ["", "Allow", "Block"],
                  coalesce(try(config.defaultConnectorActionRuleBehavior, null), "")
                ) &&
                alltrue([
                  for rule in coalesce(try(config.actionRules, null), []) :
                  trimspace(rule.actionId) != "" && contains(["Allow", "Block"], rule.behavior)
                ]),
                false
              )
            ]) &&
            length(distinct([
              for config in coalesce(try(jsondecode(self.output.body).connectorConfigurationsDefinition.connectorActionConfigurations, null), []) :
              config.connectorId
            ])) == length(coalesce(try(jsondecode(self.output.body).connectorConfigurationsDefinition.connectorActionConfigurations, null), [])) &&
            alltrue([
              for config in coalesce(try(jsondecode(self.output.body).connectorConfigurationsDefinition.endpointConfigurations, null), []) :
              try(
                trimspace(config.connectorId) != "" &&
                alltrue([
                  for rule in coalesce(try(config.endpointRules, null), []) :
                  can(rule.order + 0) &&
                  trimspace(rule.endpoint) != "" &&
                  contains(["Allow", "Deny"], rule.behavior)
                ]),
                false
              )
            ]) &&
            length(distinct([
              for config in coalesce(try(jsondecode(self.output.body).connectorConfigurationsDefinition.endpointConfigurations, null), []) :
              config.connectorId
            ])) == length(coalesce(try(jsondecode(self.output.body).connectorConfigurationsDefinition.endpointConfigurations, null), [])),
            false
          )
        ) &&
        (
          try(jsondecode(self.output.body).customConnectorUrlPatternsDefinition == null, true) ||
          try(
            alltrue([
              for rule in coalesce(try(jsondecode(self.output.body).customConnectorUrlPatternsDefinition.rules, null), []) :
              try(
                can(rule.order + 0) &&
                trimspace(rule.pattern) != "" &&
                contains(["General", "Confidential", "Blocked", "Ignore"], rule.customConnectorRuleClassification),
                false
              )
            ]),
            false
          )
        ),
        false
      )
      error_message = "The DLP policy detail response has an unexpected shape or no longer matches the requested policy. The policy could have changed or been deleted after listing."
    }
  }
}

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
