# Basic Example

Minimal configuration to replicate an existing DLP policy into a `.tfvars` file.
Only `source_policy_name` is required.

> **Note:** The default `source_policy_name` value (`"My DLP Policy"`) is a placeholder. Replace it with the exact display name of an existing DLP policy in your tenant, or `policy_found` will be `false` and no `.tfvars` file will be written.
