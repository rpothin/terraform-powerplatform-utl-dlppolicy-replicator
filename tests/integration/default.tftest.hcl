# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#   TF_VAR_source_policy_name=<existing-policy-name>
#   TF_VAR_source_policy_name_b=<second-existing-policy-name>  (optional, for batch tests)

variable "source_policy_name" {
  description = "Display name of an existing DLP policy to replicate in integration tests."
  type        = string
}

variable "source_policy_name_b" {
  description = "Display name of a second existing DLP policy for batch integration tests. Optional — when not set, batch tests skip the two-policy scenario."
  type        = string
  default     = null
  nullable    = true
}

run "replicates_existing_policy" {
  command = apply

  variables {
    source_policy_name = var.source_policy_name
  }

  assert {
    condition     = output.policy_found == true
    error_message = "Policy should have been found. Check TF_VAR_source_policy_name is set to an existing policy name."
  }

  assert {
    condition     = output.tfvars_file_path != null
    error_message = "tfvars file should have been written when policy is found."
  }

  assert {
    condition     = !strcontains(output.generated_tfvars_content, "non_business_connectors")
    error_message = "Generated tfvars must not contain non_business_connectors (unsupported by res-dlppolicy)."
  }

  assert {
    condition     = !strcontains(output.generated_tfvars_content, "blocked_connectors =")
    error_message = "Generated tfvars must not contain blocked_connectors (unsupported by res-dlppolicy)."
  }

  assert {
    condition     = !contains([for p in output.custom_connectors_patterns : p.host_url_pattern], "*")
    error_message = "Wildcard '*' custom connector pattern must be stripped from custom_connectors_patterns."
  }
}

run "missing_policy_does_not_fail" {
  # Use plan — no resources to create, so apply is an unnecessary live API round-trip.
  command = plan

  variables {
    source_policy_name = "tftest-nonexistent-policy-that-should-not-exist"
  }

  assert {
    condition     = output.policy_found == false
    error_message = "Non-existent policy should result in policy_found = false."
  }

  assert {
    condition     = output.tfvars_file_path == null
    error_message = "No file should be written when policy is not found."
  }
}

run "batch_found_policy_produces_result" {
  command = apply

  variables {
    source_policy_name  = null
    source_policy_names = [var.source_policy_name]
    output_files = {
      (var.source_policy_name) = "tftest-batch-policy-a.tfvars"
    }
  }

  assert {
    condition     = output.batch_results[var.source_policy_name].status == "found"
    error_message = "batch_results status should be 'found' for an existing policy."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name].found == true
    error_message = "batch_results.found should be true for an existing policy."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name].tfvars_content != ""
    error_message = "batch_results.tfvars_content should be non-empty for a found policy."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name].file_path == "tftest-batch-policy-a.tfvars"
    error_message = "batch_results.file_path should match the output_files entry."
  }

  assert {
    condition     = output.batch_file_paths[var.source_policy_name] == "tftest-batch-policy-a.tfvars"
    error_message = "batch_file_paths should contain the written file path for a found policy."
  }

  assert {
    condition     = !strcontains(output.batch_results[var.source_policy_name].tfvars_content, "non_business_connectors")
    error_message = "Batch tfvars content must not contain non_business_connectors."
  }
}

run "batch_missing_policy_is_soft_miss" {
  command = plan

  variables {
    source_policy_name  = null
    source_policy_names = ["tftest-nonexistent-policy-that-should-not-exist"]
  }

  assert {
    condition     = output.batch_results["tftest-nonexistent-policy-that-should-not-exist"].status == "not_found"
    error_message = "Missing policy should produce status = not_found in batch_results."
  }

  assert {
    condition     = output.batch_results["tftest-nonexistent-policy-that-should-not-exist"].found == false
    error_message = "Missing policy should produce found = false in batch_results."
  }

  assert {
    condition     = output.batch_results["tftest-nonexistent-policy-that-should-not-exist"].tfvars_content == ""
    error_message = "Missing policy should produce no tfvars_content."
  }

  assert {
    condition     = output.batch_file_paths == {}
    error_message = "batch_file_paths should be empty when no policies are found."
  }
}

run "batch_independent_soft_miss_does_not_affect_found" {
  command = apply

  variables {
    source_policy_name  = null
    source_policy_names = [var.source_policy_name, "tftest-nonexistent-policy-that-should-not-exist"]
    output_files = {
      (var.source_policy_name) = "tftest-batch-policy-a-mixed.tfvars"
    }
  }

  assert {
    condition     = output.batch_results[var.source_policy_name].found == true
    error_message = "Found policy should still be found when a missing policy is in the same batch."
  }

  assert {
    condition     = output.batch_results["tftest-nonexistent-policy-that-should-not-exist"].status == "not_found"
    error_message = "Missing policy should be not_found even when another policy in the batch is found."
  }

  assert {
    condition     = output.batch_file_paths[var.source_policy_name] == "tftest-batch-policy-a-mixed.tfvars"
    error_message = "Found policy file path should be written even when another policy in the batch is missing."
  }
}

run "batch_stable_keys_not_renumbered" {
  # Verifies that removing/adding a requested name does not change keys of existing entries.
  # Re-runs with only the first policy to confirm the key is still the same string.
  command = apply

  variables {
    source_policy_name  = null
    source_policy_names = [var.source_policy_name]
    output_files = {
      (var.source_policy_name) = "tftest-batch-stable-key.tfvars"
    }
  }

  assert {
    condition     = output.batch_results[var.source_policy_name].requested_name == var.source_policy_name
    error_message = "Batch result key must be the exact requested name, not a renumbered index."
  }
}

