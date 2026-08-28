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

###############################################################################
# Tests 17–20: Additional output-null guards and variable reflection tests
#
# MOCK FRAMEWORK LIMITATION (Terraform v1.14.x):
# The nested_type attributes with nesting_mode:list (policies, connectors) and
# nesting_mode:set (business_connectors, etc.) cannot be populated through
# override_data or mock_data defaults — any tuple literal produces
# "incompatible types; expected object type, found tuple" and tolist/toset
# coercions are not evaluated before the type check. The mock auto-generates
# empty lists, so all tests below verify module behaviour with empty nested
# collections (policy not found / no connectors), which is equivalent to a
# policy that exists with no connectors or environments.
#
# Positive-path transformation logic (connector projection, wildcard stripping,
# environment normalisation, reclassification detection) is covered by
# tests/integration/default.tftest.hcl using real provider calls.
###############################################################################

###############################################################################
# Test 17: display_name output is the matched policy name when policy found
#          (mock always returns empty policies, so policy_found == false;
#           verifies null guard on display_name output)
###############################################################################
run "display_name_null_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Any Policy"
  }

  assert {
    condition     = output.display_name == null
    error_message = "display_name should be null when no policy is found."
  }
}

###############################################################################
# Test 18: migration_summary.preserve_connector_rules reflects the variable
###############################################################################
run "migration_summary_reflects_preserve_connector_rules_true" {
  command = plan

  variables {
    source_policy_name       = "Any Policy"
    preserve_connector_rules = true
  }

  assert {
    condition     = output.migration_summary.preserve_connector_rules == true
    error_message = "migration_summary.preserve_connector_rules should be true when the variable is set to true."
  }
}

###############################################################################
# Test 19: environment_type output is null when policy not found
###############################################################################
run "environment_type_null_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Any Policy"
  }

  assert {
    condition     = output.environment_type == null
    error_message = "environment_type should be null when no policy is found."
  }
}

###############################################################################
# Test 20: default_connectors_classification output is null when policy not found
###############################################################################
run "default_connectors_classification_null_when_policy_not_found" {
  command = plan

  variables {
    source_policy_name = "Any Policy"
  }

  assert {
    condition     = output.default_connectors_classification == null
    error_message = "default_connectors_classification should be null when no policy is found."
  }
}

###############################################################################
# NEW BATCH MODE VALIDATION TESTS
###############################################################################

###############################################################################
# Test 21: Rejects both source_policy_name and source_policy_names set together
###############################################################################
run "rejects_both_scalar_and_batch_set" {
  command = plan

  variables {
    source_policy_name  = "Policy A"
    source_policy_names = ["Policy B"]
  }

  expect_failures = [
    var.source_policy_names,
  ]
}

###############################################################################
# Test 22: Rejects neither mode (both null) — needs at least one
###############################################################################
run "rejects_neither_mode_set" {
  command = plan

  variables {
    # Both source_policy_name and source_policy_names are null (their defaults).
    # The exactly-one-mode validation on source_policy_names must reject this.
    source_policy_names = null
  }

  expect_failures = [
    var.source_policy_names,
  ]
}

###############################################################################
# Test 23: Rejects empty source_policy_names list
###############################################################################
run "rejects_empty_source_policy_names_list" {
  command = plan

  variables {
    source_policy_names = []
  }

  expect_failures = [
    var.source_policy_names,
  ]
}

###############################################################################
# Test 24: Rejects blank entry in source_policy_names
###############################################################################
run "rejects_blank_entry_in_source_policy_names" {
  command = plan

  variables {
    source_policy_names = ["Valid Policy", "   "]
  }

  expect_failures = [
    var.source_policy_names,
  ]
}

###############################################################################
# Test 25: Rejects overlong entry in source_policy_names (> 256 chars)
###############################################################################
run "rejects_overlong_entry_in_source_policy_names" {
  command = plan

  variables {
    source_policy_names = ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
  }

  expect_failures = [
    var.source_policy_names,
  ]
}

###############################################################################
# Test 26: Rejects duplicate entries in source_policy_names
###############################################################################
run "rejects_duplicate_entries_in_source_policy_names" {
  command = plan

  variables {
    source_policy_names = ["Policy A", "Policy B", "Policy A"]
  }

  expect_failures = [
    var.source_policy_names,
  ]
}

###############################################################################
# Test 27: Accepts valid source_policy_names list
###############################################################################
run "accepts_valid_source_policy_names" {
  command = plan

  variables {
    source_policy_names = ["Policy A", "Policy B"]
  }

  assert {
    condition     = var.source_policy_names == tolist(["Policy A", "Policy B"])
    error_message = "source_policy_names should be accepted when valid."
  }
}

###############################################################################
# Test 28: batch_results is empty map in scalar mode
###############################################################################
run "batch_results_empty_in_scalar_mode" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
  }

  assert {
    condition     = output.batch_results == {}
    error_message = "batch_results should be an empty map when in scalar mode."
  }
}

###############################################################################
# Test 29: batch_results contains not_found status for all names
#          (mock returns empty policies list so all names are not_found)
###############################################################################
run "batch_results_not_found_status_with_mock" {
  command = plan

  variables {
    source_policy_names = ["Policy A", "Policy B"]
  }

  assert {
    condition     = output.batch_results["Policy A"].status == "not_found"
    error_message = "batch_results[Policy A].status should be 'not_found' when mock returns empty policies."
  }

  assert {
    condition     = output.batch_results["Policy B"].status == "not_found"
    error_message = "batch_results[Policy B].status should be 'not_found' when mock returns empty policies."
  }
}

###############################################################################
# Test 30: batch_results found flag is false for all names with mock
###############################################################################
run "batch_results_found_false_with_mock" {
  command = plan

  variables {
    source_policy_names = ["Policy A", "Policy B"]
  }

  assert {
    condition     = output.batch_results["Policy A"].found == false
    error_message = "batch_results[Policy A].found should be false when mock returns empty policies."
  }

  assert {
    condition     = output.batch_results["Policy B"].found == false
    error_message = "batch_results[Policy B].found should be false when mock returns empty policies."
  }
}

###############################################################################
# Test 31: batch_results tfvars_content is empty for not_found policies
###############################################################################
run "batch_results_no_tfvars_content_for_not_found" {
  command = plan

  variables {
    source_policy_names = ["Policy A"]
  }

  assert {
    condition     = output.batch_results["Policy A"].tfvars_content == ""
    error_message = "batch_results tfvars_content should be empty for not_found policies."
  }
}

###############################################################################
# Test 32: batch_results file_path is null for not_found policies
###############################################################################
run "batch_results_file_path_null_for_not_found" {
  command = plan

  variables {
    source_policy_names = ["Policy A"]
    output_files = {
      "Policy A" = "policy-a.tfvars"
    }
  }

  assert {
    condition     = output.batch_results["Policy A"].file_path == null
    error_message = "batch_results file_path should be null when the policy is not found (regardless of output_files entry)."
  }
}

###############################################################################
# Test 33: batch_file_paths is empty map in scalar mode
###############################################################################
run "batch_file_paths_empty_in_scalar_mode" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
  }

  assert {
    condition     = output.batch_file_paths == {}
    error_message = "batch_file_paths should be an empty map in scalar mode."
  }
}

###############################################################################
# Test 34: batch_file_paths is empty when no policies found (all not_found)
###############################################################################
run "batch_file_paths_empty_when_no_policies_found" {
  command = plan

  variables {
    source_policy_names = ["Policy A", "Policy B"]
    output_files = {
      "Policy A" = "policy-a.tfvars"
      "Policy B" = "policy-b.tfvars"
    }
  }

  assert {
    condition     = output.batch_file_paths == {}
    error_message = "batch_file_paths should be empty when no policies are found."
  }
}

###############################################################################
# Test 35: Rejects output_files with non-.tfvars extension
###############################################################################
run "rejects_output_files_non_tfvars_extension" {
  command = plan

  variables {
    source_policy_names = ["Policy A"]
    output_files = {
      "Policy A" = "policy-a.txt"
    }
  }

  expect_failures = [
    var.output_files,
  ]
}

###############################################################################
# Test 36: Rejects output_files key not in source_policy_names
###############################################################################
run "rejects_output_files_key_not_in_source_policy_names" {
  command = plan

  variables {
    source_policy_names = ["Policy A"]
    output_files = {
      "Policy A"       = "policy-a.tfvars"
      "Unknown Policy" = "unknown.tfvars"
    }
  }

  expect_failures = [
    var.output_files,
  ]
}

###############################################################################
# Test 37: Rejects output_files in scalar mode (must be empty)
###############################################################################
run "rejects_output_files_in_scalar_mode" {
  command = plan

  variables {
    source_policy_name = "My DLP Policy"
    output_files = {
      "My DLP Policy" = "my-policy.tfvars"
    }
  }

  expect_failures = [
    var.output_files,
  ]
}

###############################################################################
# Test 38: policy_found is false in batch mode (scalar output is batch-inactive)
###############################################################################
run "policy_found_false_in_batch_mode" {
  command = plan

  variables {
    source_policy_names = ["Policy A"]
  }

  assert {
    condition     = output.policy_found == false
    error_message = "policy_found (scalar output) should be false when in batch mode."
  }
}

###############################################################################
# Test 39: batch_results preserves exact requested_name field
###############################################################################
run "batch_results_preserves_requested_name" {
  command = plan

  variables {
    source_policy_names = ["My Exact Policy Name"]
  }

  assert {
    condition     = output.batch_results["My Exact Policy Name"].requested_name == "My Exact Policy Name"
    error_message = "batch_results.requested_name must equal the original requested name."
  }
}

###############################################################################
# Test 40: batch_results migration_summary reflects preserve_connector_rules
###############################################################################
run "batch_results_migration_summary_reflects_preserve_rules" {
  command = plan

  variables {
    source_policy_names      = ["Policy A"]
    preserve_connector_rules = true
  }

  assert {
    condition     = output.batch_results["Policy A"].migration_summary.preserve_connector_rules == true
    error_message = "batch_results.migration_summary.preserve_connector_rules should be true when the variable is set."
  }
}

###############################################################################
# Test 42: batch advisory check — _batch_reclassified_connector_ids is empty
#          when mock returns no connectors (all batch policies are not_found)
###############################################################################
run "batch_reclassified_connector_ids_empty_with_mock" {
  command = plan

  variables {
    source_policy_names = ["Policy A", "Policy B"]
  }

  # With mock provider all policies are not_found, so no batch details exist
  # and _batch_reclassified_connector_ids must be empty.
  # The check block no_blockable_connectors_in_non_business_batch must pass.
  assert {
    condition     = length(output.batch_results["Policy A"].connectors_reclassified_to_blocked) == 0
    error_message = "batch_results connectors_reclassified_to_blocked should be empty when policies are not found."
  }

  assert {
    condition     = length(output.batch_results["Policy B"].connectors_reclassified_to_blocked) == 0
    error_message = "batch_results connectors_reclassified_to_blocked should be empty when policies are not found."
  }
}

run "rejects_whitespace_only_source_policy_name" {
  command = plan

  variables {
    source_policy_name = "   "
  }

  expect_failures = [
    var.source_policy_name,
  ]
}

