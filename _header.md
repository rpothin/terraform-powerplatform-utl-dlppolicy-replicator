# `utl-dlppolicy-replicator` — Power Platform DLP Policy Replicator

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-blue.svg)](https://registry.terraform.io/modules/rpothin/utl-dlppolicy-replicator/powerplatform)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/rpothin/terraform-powerplatform-utl-dlppolicy-replicator/blob/main/LICENSE)

Reads existing Power Platform DLP policies from a live tenant and generates `.tfvars` files compatible with [`rpothin/res-dlppolicy/powerplatform`](https://registry.terraform.io/modules/rpothin/res-dlppolicy/powerplatform).

Use this module once to migrate one or more admin-center-managed DLP policies into Terraform governance via `res-dlppolicy`.

The provider connector catalog is canonicalized by connector ID before classification, so duplicate records from overlapping metadata endpoints do not cause Terraform duplicate-key failures. When duplicate records disagree, an ID is treated as unblockable if any record marks it as unblockable.

> **Tip:** Add the generated `.tfvars` files to your `.gitignore` — they contain environment IDs and connector configurations that vary by tenant.

## Mode Selection

The module operates in one of two mutually exclusive modes. Exactly one of the two inputs below must be set:

| Mode | Input | When to use |
|---|---|---|
| **Scalar** | `source_policy_name = "My Policy"` | Replicate a single policy. Preserves the existing `local_file.generated_tfvars[0]` state address. |
| **Batch** | `source_policy_names = ["Policy A", "Policy B"]` | Replicate multiple policies in one invocation, amortising the tenant-wide data-source reads across all requested names. |

### Batch mode

- Each name is resolved independently. A **missing** policy is a soft miss (`status = "not_found"`) — it does not block other names in the same batch.
- An **ambiguous** name (two or more tenant policies share the same display name) surfaces as `status = "ambiguous"` and produces **no file**, preventing an incorrect snapshot.
- File destinations are caller-controlled through the `output_files` map (keys = requested names, values = `.tfvars` paths). Only `found` policies with a matching key in `output_files` produce a file.
- Result keys in `batch_results` are the **exact requested strings** — no sanitisation. State addresses (`local_file.generated_tfvars_batch["My Policy"]`) are therefore stable when you add or remove other names from the batch.

## Prerequisites

- The calling service principal must have the **Power Platform Administrator** role.
- OIDC authentication must be configured (see [Authentication](#authentication) below).
- In scalar mode, the policy display name must be **unique** within the tenant scope — `one()` will error on an ambiguous match.
- In batch mode, ambiguous names are surfaced as `status = "ambiguous"` rather than erroring the whole operation.

## Known Behaviour Changes After Migration

When you apply the generated `.tfvars` with `res-dlppolicy`, the following behavioural changes may occur:

| Behaviour | Details |
|---|---|
| **Wildcard custom-connector pattern removed** | `res-dlppolicy` appends `host_url_pattern = "*"` automatically. Any `"*"` entry in the source policy is stripped from the generated tfvars. |
| **NonBusiness → Blocked reclassification** | `res-dlppolicy` auto-computes the NonBusiness group from the connector catalog. Blockable connectors currently in NonBusiness **will be reclassified to Blocked**. Review `connectors_reclassified_to_blocked` (scalar) or `batch_results[name].connectors_reclassified_to_blocked` (batch) before applying. |
| **Connector rules stripped by default** | `action_rules` and `endpoint_rules` on business connectors are stripped unless `preserve_connector_rules = true`. |
| **Perpetual plan diff** | `timestamp()` is used in the generated file header and in `migration_summary.generation_timestamp`. Each `terraform plan` will show diffs on `generated_tfvars_content`/`batch_results[*].tfvars_content` and the corresponding summary timestamps. This is intentional for a one-shot migration utility — apply once, then discard the module. |
| **`terraform destroy` deletes the generated files** | Running `terraform destroy` removes any `.tfvars` files written by this module. Re-run `terraform apply` to regenerate them. |
| **Reclassification check runs on every plan** | The advisory `check` block re-evaluates the scalar-mode policy against the live source on every `terraform plan`. It is not a one-shot gate. It does not run per-policy in batch mode. |

