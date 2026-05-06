# `utl-dlppolicy-replicator` — Power Platform DLP Policy Replicator

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-blue.svg)](https://registry.terraform.io/modules/rpothin/utl-dlppolicy-replicator/powerplatform)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/rpothin/terraform-powerplatform-utl-dlppolicy-replicator/blob/main/LICENSE)

Reads an existing Power Platform DLP policy from a live tenant and generates a `.tfvars` file compatible with [`rpothin/res-dlppolicy/powerplatform`](https://registry.terraform.io/modules/rpothin/res-dlppolicy/powerplatform).

Use this module once to migrate an admin-center-managed DLP policy into Terraform governance via `res-dlppolicy`.

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
| **Perpetual plan diff on tfvars content** | `timestamp()` is used in the generated file header. Each `terraform plan` will show a diff on `generated_tfvars_content`. This is intentional for a one-shot migration utility. |