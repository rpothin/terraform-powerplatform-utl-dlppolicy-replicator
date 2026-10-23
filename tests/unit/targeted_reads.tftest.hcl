mock_provider "powerplatform" {
  mock_data "powerplatform_rest_query" {
    defaults = {
      output = {
        body = jsonencode({ value = [] })
      }
    }
  }
}

mock_provider "local" {}

override_data {
  target = data.powerplatform_rest_query.policies_list
  values = {
    output = {
      body = jsonencode({
        value = [{
          policyDefinition = {
            name        = "policy-id"
            displayName = "Unit Policy"
          }
        }]
      })
    }
  }
}

override_data {
  target = data.powerplatform_rest_query.policy["Unit Policy"]
  values = {
    output = {
      body = jsonencode({
        policyDefinition = {
          name                             = "policy-id"
          displayName                      = "Unit Policy"
          defaultConnectorsClassification = "General"
          environmentType                  = "OnlyEnvironments"
          environments = [
            { name = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB" },
            { name = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA" },
          ]
          connectorGroups = [
            {
              classification = "Confidential"
              connectors     = [{ id = "connector-business" }]
            },
            {
              classification = "General"
              connectors     = [{ id = "connector-nonbusiness" }]
            },
            {
              classification = "Blocked"
              connectors     = []
            },
          ]
        }
        connectorConfigurationsDefinition = {
          connectorActionConfigurations = [{
            connectorId                            = "connector-business"
            defaultConnectorActionRuleBehavior     = "Allow"
            actionRules                            = [{ actionId = "action-1", behavior = "Block" }]
          }]
          endpointConfigurations = [{
            connectorId = "connector-business"
            endpointRules = [{
              order    = 1
              endpoint = "https://example.invalid"
              behavior = "Deny"
            }]
          }]
        }
        customConnectorUrlPatternsDefinition = {
          rules = [
            {
              order                             = 1
              pattern                           = "api.example.invalid"
              customConnectorRuleClassification = "Confidential"
            },
            {
              order                             = 2
              pattern                           = "*"
              customConnectorRuleClassification = "General"
            },
            {
              order                             = 3
              pattern                           = "ignore.example.invalid"
              customConnectorRuleClassification = "Ignore"
            },
            {
              order                             = 4
              pattern                           = "general.example.invalid"
              customConnectorRuleClassification = "General"
            },
          ]
        }
      })
    }
  }
}

run "scalar_targeted_read_projects_policy_details" {
  command = plan

  variables {
    source_policy_name       = "Unit Policy"
    preserve_connector_rules = true
  }

  assert {
    condition     = data.powerplatform_rest_query.policies_list.method == "GET" && data.powerplatform_rest_query.policies_list.url == "https://${var.bapi_host}/providers/PowerPlatform.Governance/v2/policies" && data.powerplatform_rest_query.policies_list.scope == var.bapi_scope && length(data.powerplatform_rest_query.policy) == 1
    error_message = "Scalar mode must make one list query and one detail query for the uniquely matched policy."
  }

  assert {
    condition     = output.policy_found && output.display_name == "Unit Policy"
    error_message = "The targeted detail response should be projected as the selected policy."
  }

  assert {
    condition     = output.environments == ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
    error_message = "Environment IDs must remain lowercased and sorted."
  }

  assert {
    condition     = length(output.business_connectors) == 1 && output.business_connectors[0].id == "connector-business" && output.business_connectors[0].default_action_rule_behavior == "Allow"
    error_message = "The Confidential connector group must map to business_connectors."
  }

  assert {
    condition     = output.business_connectors[0].action_rules == [{ action_id = "action-1", behavior = "Block" }] && output.business_connectors[0].endpoint_rules == [{ order = 1, endpoint = "https://example.invalid", behavior = "Deny" }]
    error_message = "Connector action and endpoint rules must be preserved when requested."
  }

  assert {
    condition     = length(output.custom_connectors_patterns) == 3 && one([for pattern in output.custom_connectors_patterns : pattern.data_group if pattern.order == 1]) == "Business"
    error_message = "Custom patterns must map Confidential to Business and remove wildcard entries."
  }

  assert {
    condition     = one([for pattern in output.custom_connectors_patterns : pattern.data_group if pattern.order == 3]) == "Ignore"
    error_message = "Custom patterns must preserve classifications accepted by the provider's data source."
  }

  assert {
    condition     = one([for pattern in output.custom_connectors_patterns : pattern.data_group if pattern.order == 4]) == "NonBusiness"
    error_message = "Custom patterns must map General to NonBusiness."
  }
}

run "batch_targeted_read_projects_policy_details" {
  command = plan

  variables {
    source_policy_name  = null
    source_policy_names = ["Unit Policy"]
  }

  assert {
    condition     = data.powerplatform_rest_query.policies_list.method == "GET" && length(data.powerplatform_rest_query.policy) == 1
    error_message = "Batch mode must make one list query and one detail query for the uniquely matched policy."
  }

  assert {
    condition     = output.batch_results["Unit Policy"].status == "found" && output.batch_results["Unit Policy"].display_name == "Unit Policy"
    error_message = "The batch result must reuse the targeted policy projection."
  }

  assert {
    condition     = output.batch_results["Unit Policy"].business_connectors[0].action_rules == [] && output.batch_results["Unit Policy"].business_connectors[0].endpoint_rules == []
    error_message = "Connector rules must remain stripped by default in batch mode."
  }
}
