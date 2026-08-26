# `utl-dlppolicy-replicator` — Power Platform DLP Policy Replicator

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-blue.svg)](https://registry.terraform.io/modules/rpothin/utl-dlppolicy-replicator/powerplatform)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/rpothin/terraform-powerplatform-utl-dlppolicy-replicator/blob/main/LICENSE)

Reads an existing Power Platform DLP policy from a live tenant and generates a `.tfvars` file compatible with [`rpothin/res-dlppolicy/powerplatform`](https://registry.terraform.io/modules/rpothin/res-dlppolicy/powerplatform).

Use this module once to migrate an admin-center-managed DLP policy into Terraform governance via `res-dlppolicy`.

The provider connector catalog is canonicalized by connector ID before classification, so duplicate records from overlapping metadata endpoints do not cause Terraform duplicate-key failures. When duplicate records disagree, an ID is treated as unblockable if any record marks it as unblockable.

> **Tip:** Add the generated `.tfvars` file to your `.gitignore` — it contains environment IDs and connector configurations that vary by tenant.

## Prerequisites

- The calling service principal must have the **Power Platform Administrator** role.
- OIDC authentication must be configured (see [Authentication](#authentication) below).
- DLP policy display names must be **unique** within the tenant scope — if two policies share the same name, `one()` will error.

## Known Behaviour Changes After Migration

When you apply the generated `.tfvars` with `res-dlppolicy`, the following behavioural changes may occur:

| Behaviour | Details |
|---|---|
| **Wildcard custom-connector pattern removed** | `res-dlppolicy` appends `host_url_pattern = "*"` automatically. Any `"*"` entry in the source policy is stripped from the generated tfvars. |
| **NonBusiness → Blocked reclassification** | `res-dlppolicy` auto-computes the NonBusiness group from the connector catalog. Blockable connectors currently in NonBusiness **will be reclassified to Blocked**. Review `connectors_reclassified_to_blocked` output before applying. |
| **Connector rules stripped by default** | `action_rules` and `endpoint_rules` on business connectors are stripped unless `preserve_connector_rules = true`. |
| **Perpetual plan diff** | `timestamp()` is used in the generated file header and in the `migration_summary.generation_timestamp` output. Each `terraform plan` will show diffs on `generated_tfvars_content` and `migration_summary`. This is intentional for a one-shot migration utility — apply once, then discard the module. |
| **`terraform destroy` deletes the generated file** | Running `terraform destroy` removes the `.tfvars` file written by this module. Re-run `terraform apply` to regenerate it. |
| **Reclassification check runs on every plan** | The advisory `check` block re-evaluates against the live source policy on every `terraform plan`. It is not a one-shot gate — it re-fires whenever the source policy changes. |
