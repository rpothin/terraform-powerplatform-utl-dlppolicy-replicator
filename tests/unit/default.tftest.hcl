# Unit tests — uses mock providers, no credentials required.
# Mock data structures are derived from the real provider schema (microsoft/power-platform ~> 4.0).
#
# MOCK LIMITATION:
# The `powerplatform_data_loss_prevention_policies` and `powerplatform_connectors` data sources
# use `nested_type` attributes with `nesting_mode: list`. Terraform's mock provider framework
# (v1.14.x) cannot populate these attributes via override_data or mock_data defaults — any attempt
# to supply list literals results in "incompatible types; expected object type, found tuple" errors,
# and object literals are silently ignored. The mock auto-generates empty lists.
#
# Consequence: unit tests can only exercise the "policy not found" / empty-data code paths and
# variable validation.  All positive-path logic (policy found, connector reclassification,
# wildcard stripping, environment normalisation) is covered by tests/integration/default.tftest.hcl.

mock_provider "powerplatform" {}

mock_provider "local" {}

###############################################################################
# Test 1: Policy not found when mock returns empty policies list
###############################################################################
run "policy_not_found_with_mock_empty_policies" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
  }

  assert {
    condition     = output.policy_found == false
    error_message = "policy_found should be false when the mock provider returns an empty policies list."
  }
}

###############################################################################
# Test 2: tfvars_file_path is null when policy not found
###############################################################################
run "tfvars_file_path_null_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Nonexistent Policy Name"
  }

  assert {
    condition     = output.tfvars_file_path == null
    error_message = "tfvars_file_path should be null when the policy is not found."
  }
}

###############################################################################
# Test 3: generated_tfvars_content is empty when policy not found
###############################################################################
run "generated_tfvars_content_empty_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = output.generated_tfvars_content == ""
    error_message = "generated_tfvars_content should be an empty string when the policy is not found."
  }
}

###############################################################################
# Test 4: non_business_connectors never appears in tfvars content
###############################################################################
run "non_business_connectors_not_in_tfvars" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = !strcontains(output.generated_tfvars_content, "non_business_connectors")
    error_message = "Generated tfvars content must never contain 'non_business_connectors' (unsupported by res-dlppolicy)."
  }
}

###############################################################################
# Test 5: blocked_connectors never appears in tfvars content
###############################################################################
run "blocked_connectors_not_in_tfvars" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = !strcontains(output.generated_tfvars_content, "blocked_connectors =")
    error_message = "Generated tfvars content must never contain 'blocked_connectors =' (unsupported by res-dlppolicy)."
  }
}

###############################################################################
# Test 6: connectors_reclassified_to_blocked is empty when policy not found
###############################################################################
run "connectors_reclassified_to_blocked_empty_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = length(output.connectors_reclassified_to_blocked) == 0
    error_message = "connectors_reclassified_to_blocked should be empty when no policy is found."
  }
}

###############################################################################
# Test 7: business_connectors output is empty list when policy not found
###############################################################################
run "business_connectors_empty_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = output.business_connectors == []
    error_message = "business_connectors should be an empty list when policy is not found."
  }
}

###############################################################################
# Test 8: environments output is empty list when policy not found
###############################################################################
run "environments_empty_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = output.environments == []
    error_message = "environments should be an empty list when policy is not found."
  }
}

###############################################################################
# Test 9: custom_connectors_patterns output is empty list when policy not found
###############################################################################
run "custom_connectors_patterns_empty_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = output.custom_connectors_patterns == []
    error_message = "custom_connectors_patterns should be an empty list when policy is not found."
  }
}

###############################################################################
# Test 10: preserve_connector_rules default is false
###############################################################################
run "preserve_connector_rules_defaults_to_false" {
  command = plan

  variables {
    source_policy_name = "Some Policy"
  }

  assert {
    condition     = var.preserve_connector_rules == false
    error_message = "preserve_connector_rules should default to false."
  }
}

###############################################################################
# Test 11: migration_summary reflects correct metadata when policy not found
###############################################################################
run "migration_summary_correct_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Audit Policy"
  }

  assert {
    condition     = output.migration_summary.policy_found == false
    error_message = "migration_summary.policy_found should be false when policy is not found."
  }

  assert {
    condition     = output.migration_summary.source_policy_name == "Audit Policy"
    error_message = "migration_summary.source_policy_name should match the input variable."
  }

  assert {
    condition     = output.migration_summary.business_connector_count == 0
    error_message = "migration_summary.business_connector_count should be 0 when policy is not found."
  }

  assert {
    condition     = output.migration_summary.reclassified_connector_count == 0
    error_message = "migration_summary.reclassified_connector_count should be 0 when policy is not found."
  }
}

###############################################################################
# Test 12: Rejects empty source_policy_name (< 1 char)
###############################################################################
run "rejects_empty_source_policy_name" {
  command = plan

  variables {
    source_policy_name = ""
  }

  expect_failures = [
    var.source_policy_name,
  ]
}

###############################################################################
# Test 13: Rejects source_policy_name exceeding 256 characters
###############################################################################
run "rejects_source_policy_name_too_long" {
  command = plan

  variables {
    source_policy_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [
    var.source_policy_name,
  ]
}

###############################################################################
# Test 14: Rejects output_file without .tfvars extension
###############################################################################
run "rejects_non_tfvars_extension" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
    output_file        = "output.txt"
  }

  expect_failures = [
    var.output_file,
  ]
}

###############################################################################
# Test 15: Accepts .tfvars extension in output_file
###############################################################################
run "accepts_valid_tfvars_extension" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
    output_file        = "custom-output.tfvars"
  }

  assert {
    condition     = var.output_file == "custom-output.tfvars"
    error_message = "output_file with .tfvars extension should be accepted."
  }
}

###############################################################################
# Test 16: output_file defaults to replicated-dlp-policy.tfvars
###############################################################################
run "output_file_default_value" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
  }

  assert {
    condition     = var.output_file == "replicated-dlp-policy.tfvars"
    error_message = "output_file should default to 'replicated-dlp-policy.tfvars'."
  }
}