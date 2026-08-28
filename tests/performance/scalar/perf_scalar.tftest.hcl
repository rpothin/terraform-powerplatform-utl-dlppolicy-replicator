# Performance benchmark — scalar mode.
#
# Uses command = plan because the expensive source policy reads occur at planning
# time (data source evaluation). No file I/O is performed, which keeps the
# benchmark focused on the provider's read latency.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#   TF_VAR_source_policy_name=<existing-policy-display-name>
#
# This test is not picked up by `make test-integration` (which targets
# tests/integration only). Run it with:
#   terraform test -test-directory=tests/performance/scalar

variable "source_policy_name" {
  description = "Display name of an existing DLP policy used in the scalar performance benchmark."
  type        = string
}

run "perf_scalar_policy_found" {
  command = plan

  variables {
    source_policy_name = var.source_policy_name
  }

  assert {
    condition     = output.policy_found == true
    error_message = "Scalar performance benchmark: policy should be found. Check TF_VAR_source_policy_name is set to an existing policy display name."
  }

  assert {
    condition     = output.generated_tfvars_content != ""
    error_message = "Scalar performance benchmark: generated_tfvars_content must not be empty for a found policy."
  }
}
