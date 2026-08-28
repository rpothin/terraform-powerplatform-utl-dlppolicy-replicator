# Complete Example — Batch Mode

Full-featured example demonstrating batch extraction of multiple DLP policies in one Terraform
invocation. Supply `source_policy_names` with the exact display names of the policies to export
and an `output_files` map to control where each generated `.tfvars` file is written.

**Batch mode key behaviours:**

- Each requested policy name is looked up independently. A missing name is a soft miss (status `not_found`) that does not block other policies in the same batch.
- An ambiguous name (two or more tenant policies share the same display name) is surfaced as `status = "ambiguous"` — no file is written to avoid an incorrect snapshot.
- File paths are caller-controlled via `output_files`. Only found policies that have a corresponding key in that map produce a file.
- Result keys are the exact requested strings — no sanitisation that could collide. State addresses are therefore stable when you add or remove names from the batch.
- The same `timestamp()` perpetual-diff behaviour as scalar mode applies: each plan shows diffs on `tfvars_content` and `migration_summary.generation_timestamp`.

> **Note:** Replace the default `source_policy_names` values with the exact display names of existing DLP policies in your tenant, otherwise their status will be `not_found` and no `.tfvars` files will be written.

