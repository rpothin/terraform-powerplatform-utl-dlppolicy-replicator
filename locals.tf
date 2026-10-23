locals {
  # Canonicalize provider connector IDs before deriving DLP classifications.
  # A connector is unblockable if any duplicate provider record marks it as unblockable.
  all_connector_ids = toset([
    for c in data.powerplatform_connectors.all.connectors : c.id
  ])
  unblockable_connector_ids = toset([
    for c in data.powerplatform_connectors.all.connectors : c.id if c.unblockable
  ])
  blockable_connector_ids = setsubtract(local.all_connector_ids, local.unblockable_connector_ids)

  _policy_list_body = jsondecode(data.powerplatform_rest_query.policies_list.output.body)
  _tenant_policies  = [for policy in local._policy_list_body.value : policy.policyDefinition]

  _requested_policy_names = concat(
    var.source_policy_name != null ? [var.source_policy_name] : [],
    coalesce(var.source_policy_names, [])
  )

  _requested_match_counts = {
    for name in local._requested_policy_names :
    name => length([
      for policy in local._tenant_policies :
      policy if policy.displayName == name
    ])
  }

  _found_policy_ids = {
    for name, match_count in local._requested_match_counts :
    name => one([
      for policy in local._tenant_policies :
      policy.name if policy.displayName == name
    ])
    if match_count == 1
  }

  _raw_policy_details = {
    for name, query in data.powerplatform_rest_query.policy :
    name => jsondecode(query.output.body)
  }

  _policy_action_configurations = {
    for name, policy in local._raw_policy_details :
    name => {
      for config in coalesce(try(policy.connectorConfigurationsDefinition.connectorActionConfigurations, null), []) :
      config.connectorId => config
    }
  }

  _policy_endpoint_configurations = {
    for name, policy in local._raw_policy_details :
    name => {
      for config in coalesce(try(policy.connectorConfigurationsDefinition.endpointConfigurations, null), []) :
      config.connectorId => config
    }
  }

  # Recreate the provider's set-based groups so iteration order and deduplication
  # match the existing data source before serializing the generated tfvars.
  _policy_connector_groups = {
    for name, policy in local._raw_policy_details :
    name => {
      for normalized_group, api_group in {
        business     = "Confidential"
        non_business = "General"
        blocked      = "Blocked"
      } :
      normalized_group => [
        for connector in tolist(toset(flatten([
          for group in policy.policyDefinition.connectorGroups : [
            for connector in coalesce(try(group.connectors, null), []) : {
              id = connector.id
              default_action_rule_behavior = try(
                coalesce(local._policy_action_configurations[name][connector.id].defaultConnectorActionRuleBehavior, ""),
                ""
              )
              action_rules = [
                for rule in coalesce(try(local._policy_action_configurations[name][connector.id].actionRules, null), []) : {
                  action_id = rule.actionId
                  behavior  = rule.behavior
                }
              ]
              endpoint_rules = [
                for rule in coalesce(try(local._policy_endpoint_configurations[name][connector.id].endpointRules, null), []) : {
                  order    = rule.order
                  endpoint = rule.endpoint
                  behavior = rule.behavior
                }
              ]
            } if group.classification == api_group
          ]
        ]))) :
        {
          id                           = connector.id
          default_action_rule_behavior = connector.default_action_rule_behavior
          action_rules                 = var.preserve_connector_rules ? connector.action_rules : []
          endpoint_rules               = var.preserve_connector_rules ? connector.endpoint_rules : []
        }
      ]
    }
  }

  # This is the single normalized policy projection shared by scalar and batch modes.
  _policy_details = {
    for name, policy in local._raw_policy_details :
    name => {
      display_name                      = policy.policyDefinition.displayName
      default_connectors_classification = policy.policyDefinition.defaultConnectorsClassification
      environment_type                  = policy.policyDefinition.environmentType
      environments = sort([
        for environment in tolist(toset([
          for environment in coalesce(try(policy.policyDefinition.environments, null), []) :
          environment.name
        ])) :
        lower(environment)
      ])
      business_connectors = local._policy_connector_groups[name].business
      non_business_connectors = local._policy_connector_groups[name].non_business
      blocked_connectors      = local._policy_connector_groups[name].blocked
      custom_connectors_patterns = [
        for pattern in tolist(toset([
          for rule in coalesce(try(policy.customConnectorUrlPatternsDefinition.rules, null), []) : {
            order            = rule.order
            host_url_pattern = rule.pattern
            data_group = rule.customConnectorRuleClassification == "General" ? "NonBusiness" : (
              rule.customConnectorRuleClassification == "Confidential" ? "Business" : rule.customConnectorRuleClassification
            )
          }
        ])) :
        pattern if pattern.host_url_pattern != "*"
      ]
      connectors_reclassified_to_blocked = [
        for connector in local._policy_connector_groups[name].non_business :
        connector.id if contains(local.blockable_connector_ids, connector.id)
      ]
    }
  }

  ##############################################################################
  # SCALAR MODE
  # All scalar locals below are active only when source_policy_name is set.
  # In batch mode, selected_policy stays null and downstream scalar values are empty.
  ##############################################################################

  selected_policy = var.source_policy_name != null ? lookup(local._policy_details, var.source_policy_name, null) : null
  policy_exists   = local.selected_policy != null

  connectors_reclassified_to_blocked = local.policy_exists ? local.selected_policy.connectors_reclassified_to_blocked : []
  business_connectors                = local.policy_exists ? local.selected_policy.business_connectors : []
  custom_connectors_patterns         = local.policy_exists ? local.selected_policy.custom_connectors_patterns : []
  environments_normalised            = local.policy_exists ? local.selected_policy.environments : []

  # Generated .tfvars content with exactly the 6 res-dlppolicy variables.
  # Note: timestamp() causes a perpetual plan diff on tfvars_content; this is intentional
  # for a utility module that is run once to migrate a policy.
  # Heredoc cannot be used in a ternary, so content is built with join().
  _tfvars_lines = local.policy_exists ? [
    "# Generated by terraform-powerplatform-utl-dlppolicy-replicator",
    "# Source policy: ${var.source_policy_name}",
    "# Generated at: ${timestamp()}",
    "",
    "display_name                      = ${jsonencode(local.selected_policy.display_name)}",
    "default_connectors_classification = ${jsonencode(local.selected_policy.default_connectors_classification)}",
    "environment_type                  = ${jsonencode(local.selected_policy.environment_type)}",
    "environments                      = ${jsonencode(local.environments_normalised)}",
    "business_connectors               = ${jsonencode(local.business_connectors)}",
    "custom_connectors_patterns        = ${jsonencode(local.custom_connectors_patterns)}",
  ] : []

  tfvars_content = length(local._tfvars_lines) > 0 ? "${join("\n", local._tfvars_lines)}\n" : ""

  ##############################################################################
  # BATCH MODE
  # Active only when source_policy_names is set.
  ##############################################################################

  _batch_match_counts = {
    for name in coalesce(var.source_policy_names, []) :
    name => local._requested_match_counts[name]
  }

  _batch_policy_map = {
    for name, match_count in local._batch_match_counts :
    name => local._policy_details[name]
    if match_count == 1
  }

  _batch_details = local._batch_policy_map

  # Generated .tfvars content per found policy (same format as scalar mode).
  # timestamp() intentionally causes perpetual diffs — see module documentation.
  _batch_tfvars_content = {
    for name, details in local._batch_details :
    name => "${join("\n", [
      "# Generated by terraform-powerplatform-utl-dlppolicy-replicator",
      "# Source policy: ${name}",
      "# Generated at: ${timestamp()}",
      "",
      "display_name                      = ${jsonencode(details.display_name)}",
      "default_connectors_classification = ${jsonencode(details.default_connectors_classification)}",
      "environment_type                  = ${jsonencode(details.environment_type)}",
      "environments                      = ${jsonencode(details.environments)}",
      "business_connectors               = ${jsonencode(details.business_connectors)}",
      "custom_connectors_patterns        = ${jsonencode(details.custom_connectors_patterns)}",
    ])}\n"
  }

  # Aggregate of all connectors_reclassified_to_blocked across every found batch policy.
  # Used by the advisory check block in batch mode; empty in scalar mode.
  _batch_reclassified_connector_ids = distinct(flatten([
    for name, details in local._batch_details :
    details.connectors_reclassified_to_blocked
  ]))

  # Authoritative batch result map keyed by the original requested name.
  # Keys are always the exact requested strings — no sanitisation that could collide.
  batch_results = {
    for name in coalesce(var.source_policy_names, []) :
    name => {
      requested_name = name
      status         = local._batch_match_counts[name] == 0 ? "not_found" : (local._batch_match_counts[name] == 1 ? "found" : "ambiguous")
      found          = local._batch_match_counts[name] == 1

      display_name                       = try(local._batch_details[name].display_name, null)
      default_connectors_classification  = try(local._batch_details[name].default_connectors_classification, null)
      environment_type                   = try(local._batch_details[name].environment_type, null)
      environments                       = try(local._batch_details[name].environments, [])
      business_connectors                = try(local._batch_details[name].business_connectors, [])
      custom_connectors_patterns         = try(local._batch_details[name].custom_connectors_patterns, [])
      connectors_reclassified_to_blocked = try(local._batch_details[name].connectors_reclassified_to_blocked, [])

      # file_path is set only for found policies that have an entry in output_files.
      # Missing and ambiguous policies intentionally receive null — no file is written.
      file_path = local._batch_match_counts[name] == 1 ? lookup(var.output_files, name, null) : null

      tfvars_content = try(local._batch_tfvars_content[name], "")

      migration_summary = {
        source_policy_name             = name
        policy_found                   = local._batch_match_counts[name] == 1
        status                         = local._batch_match_counts[name] == 0 ? "not_found" : (local._batch_match_counts[name] == 1 ? "found" : "ambiguous")
        display_name                   = try(local._batch_details[name].display_name, null)
        business_connector_count       = length(try(local._batch_details[name].business_connectors, []))
        custom_connector_pattern_count = length(try(local._batch_details[name].custom_connectors_patterns, []))
        environment_count              = length(try(local._batch_details[name].environments, []))
        reclassified_connector_count   = length(try(local._batch_details[name].connectors_reclassified_to_blocked, []))
        preserve_connector_rules       = var.preserve_connector_rules
        generation_timestamp           = timestamp()
      }
    }
  }
}
