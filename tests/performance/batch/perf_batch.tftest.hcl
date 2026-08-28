# Performance benchmark — batch mode.
#
# Uses command = apply (not plan) because the module calls timestamp() inside
# locals, which makes outputs such as tfvars_content and file_path unknown at
# plan time. Running apply ensures all outputs are fully resolved so the
# non-empty content and file-path assertions below can be evaluated without
# hitting an "Unknown condition value" error.
#
# The test is still isolated: Terraform destroys all resources it creates when
# the test run completes, and the exporter writes only local files that are
# cleaned up automatically. No persistent side-effects remain after the run.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#   TF_VAR_source_policy_name_a=<existing-policy-A-display-name>
#   TF_VAR_source_policy_name_b=<existing-policy-B-display-name>
#
# This test is not picked up by `make test-integration` (which targets
# tests/integration only). Run it with:
#   terraform test -test-directory=tests/performance/batch

variable "source_policy_name_a" {
  description = "Display name of the first existing DLP policy used in the batch performance benchmark."
  type        = string
}

variable "source_policy_name_b" {
  description = "Display name of the second existing DLP policy used in the batch performance benchmark."
  type        = string
}

run "perf_batch_two_policies_found" {
  command = apply

  variables {
    source_policy_name  = null
    source_policy_names = [var.source_policy_name_a, var.source_policy_name_b]
    output_files = {
      (var.source_policy_name_a) = "perf-batch-policy-a.tfvars"
      (var.source_policy_name_b) = "perf-batch-policy-b.tfvars"
    }
  }

  assert {
    condition     = output.batch_results[var.source_policy_name_a].found == true
    error_message = "Batch performance benchmark: policy A should be found. Check TF_VAR_source_policy_name_a is set to an existing policy display name."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name_b].found == true
    error_message = "Batch performance benchmark: policy B should be found. Check TF_VAR_source_policy_name_b is set to an existing policy display name."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name_a].tfvars_content != ""
    error_message = "Batch performance benchmark: policy A tfvars_content must not be empty."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name_b].tfvars_content != ""
    error_message = "Batch performance benchmark: policy B tfvars_content must not be empty."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name_a].file_path == "perf-batch-policy-a.tfvars"
    error_message = "Batch performance benchmark: policy A file_path key must equal 'perf-batch-policy-a.tfvars'."
  }

  assert {
    condition     = output.batch_results[var.source_policy_name_b].file_path == "perf-batch-policy-b.tfvars"
    error_message = "Batch performance benchmark: policy B file_path key must equal 'perf-batch-policy-b.tfvars'."
  }
}
