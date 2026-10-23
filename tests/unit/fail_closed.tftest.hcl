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

run "rejects_paginated_policy_list" {
  command = plan

  variables {
    source_policy_name = "Unit Policy"
  }

  override_data {
    target = data.powerplatform_rest_query.policies_list
    values = {
      output = {
        body = jsonencode({
          value    = []
          nextLink = "https://example.invalid/next"
        })
      }
    }
  }

  expect_failures = [
    data.powerplatform_rest_query.policies_list,
  ]
}

run "rejects_policy_list_missing_display_name" {
  command = plan

  variables {
    source_policy_name = "Unit Policy"
  }

  override_data {
    target = data.powerplatform_rest_query.policies_list
    values = {
      output = {
        body = jsonencode({
          value = [{
            policyDefinition = {
              name = "policy-id"
            }
          }]
        })
      }
    }
  }

  expect_failures = [
    data.powerplatform_rest_query.policies_list,
  ]
}

run "rejects_ambiguous_scalar_policy_name" {
  command = plan

  variables {
    source_policy_name = "Unit Policy"
  }

  override_data {
    target = data.powerplatform_rest_query.policies_list
    values = {
      output = {
        body = jsonencode({
          value = [
            { policyDefinition = { name = "policy-id-a", displayName = "Unit Policy" } },
            { policyDefinition = { name = "policy-id-b", displayName = "Unit Policy" } },
          ]
        })
      }
    }
  }

  expect_failures = [
    data.powerplatform_rest_query.policies_list,
  ]
}

run "reports_ambiguous_batch_policy_name_without_detail_read" {
  command = plan

  variables {
    source_policy_name  = null
    source_policy_names = ["Unit Policy"]
  }

  override_data {
    target = data.powerplatform_rest_query.policies_list
    values = {
      output = {
        body = jsonencode({
          value = [
            { policyDefinition = { name = "policy-id-a", displayName = "Unit Policy" } },
            { policyDefinition = { name = "policy-id-b", displayName = "Unit Policy" } },
          ]
        })
      }
    }
  }

  assert {
    condition     = output.batch_results["Unit Policy"].status == "ambiguous" && length(data.powerplatform_rest_query.policy) == 0
    error_message = "Batch ambiguity must be reported without requesting either matching policy detail."
  }
}

run "rejects_detail_response_for_wrong_policy" {
  command = plan

  variables {
    source_policy_name = "Unit Policy"
  }

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
            name        = "unexpected-id"
            displayName = "Unit Policy"
          }
        })
      }
    }
  }

  expect_failures = [
    data.powerplatform_rest_query.policy["Unit Policy"],
  ]
}
