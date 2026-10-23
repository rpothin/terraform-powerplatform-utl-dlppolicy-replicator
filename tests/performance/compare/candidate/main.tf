terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "= 4.2.0"
    }
  }
}

variable "source_policy_name" {
  description = "Display name of the existing testing-tenant DLP policy used in the benchmark."
  type        = string
}

module "replicator" {
  source = "../../../.."

  source_policy_name = var.source_policy_name
  output_file        = "benchmark-generated.tfvars"
}

output "snapshot" {
  value = {
    policy_found                       = module.replicator.policy_found
    display_name                       = module.replicator.display_name
    default_connectors_classification  = module.replicator.default_connectors_classification
    environment_type                   = module.replicator.environment_type
    environments                       = module.replicator.environments
    business_connectors                = module.replicator.business_connectors
    custom_connectors_patterns         = module.replicator.custom_connectors_patterns
    connectors_reclassified_to_blocked = module.replicator.connectors_reclassified_to_blocked
    tfvars_file_path                   = module.replicator.tfvars_file_path
    # Compare generated values while excluding the intentionally volatile timestamp.
    generated_tfvars_content = join("\n", [
      for line in split("\n", module.replicator.generated_tfvars_content) :
      line if !startswith(line, "# Generated at:")
    ])
    migration_summary = {
      source_policy_name             = module.replicator.migration_summary.source_policy_name
      policy_found                   = module.replicator.migration_summary.policy_found
      display_name                   = module.replicator.migration_summary.display_name
      business_connector_count       = module.replicator.migration_summary.business_connector_count
      custom_connector_pattern_count = module.replicator.migration_summary.custom_connector_pattern_count
      environment_count              = module.replicator.migration_summary.environment_count
      reclassified_connector_count   = module.replicator.migration_summary.reclassified_connector_count
      preserve_connector_rules       = module.replicator.migration_summary.preserve_connector_rules
    }
    batch_results    = module.replicator.batch_results
    batch_file_paths = module.replicator.batch_file_paths
  }
}
