# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#   TF_VAR_source_policy_name=<existing-policy-name>

variable "source_policy_name" {
  description = "Display name of an existing DLP policy to replicate in integration tests."
  type        = string
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
