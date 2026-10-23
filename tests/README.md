# Tests

This directory contains Terraform native tests (`.tftest.hcl`) for the module.

## Prerequisites

- **Terraform >= 1.9** (mock providers require >= 1.7)
- **OIDC credentials** for integration and performance tests (optional)

## Test Organization

| Directory | Type | Credentials | Command |
|-----------|------|-------------|---------|
| `unit/` | Mock provider tests | None required | `command = plan` |
| `integration/` | Real provider tests | OIDC required | `command = apply` |
| `performance/compare/` | Baseline-versus-candidate benchmark | OIDC required | Opt-in GitHub Actions job |

## Running Tests

### Unit Tests

Unit tests use mock providers and require no credentials:

```bash
terraform init -backend=false
terraform test -test-directory=tests/unit
```

### Integration Tests

Integration tests create real resources and require OIDC authentication:

```bash
export POWER_PLATFORM_USE_OIDC=true
export POWER_PLATFORM_TENANT_ID=<your-tenant-id>
export POWER_PLATFORM_CLIENT_ID=<your-client-id>
export TF_VAR_source_policy_name=<existing-policy-display-name>

terraform init -backend=false
terraform test -test-directory=tests/integration
```

### Baseline-versus-candidate benchmark (opt-in)

The benchmark compares the released `v0.1.3` module with the candidate module using Power Platform provider `4.2.0` in the same GitHub Actions job and testing tenant. Both harnesses pin the same provider version to isolate the module change. It runs one scalar-policy pair, records each Terraform apply duration, and requires semantic output parity (including generated tfvars content, excluding its timestamp) plus the expected policy-read reduction. It does **not** gate on elapsed time; repeat the pair only if the recorded result looks anomalous. Consumer-tenant parity and performance are outside this change and will be checked after release.

The job requires OIDC credentials and these repository variables:

- `ENABLE_INTEGRATION_TESTS` set to `'true'`
- `ENABLE_INTEGRATION_PERFORMANCE_TESTS` set to `'true'`
- `INTEGRATION_SOURCE_POLICY_NAME` set to one existing testing-tenant policy display name

It derives the baseline read count from the `v0.1.3` provider data-source result (`N + 1` policy requests: one index request plus every tenant policy detail), and the candidate read count from its state (`1 + k`: one index request plus the targeted details). For the selected policy, `k` is one. The benchmark asserts that candidate policy-read count is lower, compares all stable policy outputs and generated tfvars content (excluding the generation timestamp), and reports baseline/candidate milliseconds in the job log and GitHub Step Summary. No live policy payload or Terraform state is uploaded or committed.

The benchmark is isolated under `tests/performance/compare/`; `make test-unit` and `make test-integration` do not invoke it. Use the explicit workflow opt-in rather than bare `terraform test`, which scans all test directories recursively.

### All Tests

> [!NOTE]
> There is no single command that safely runs all test suites, because performance tests require OIDC credentials and opt-in variables. Use the explicit `make` targets or `-test-directory` flags shown above for each suite.
>
> Bare `terraform test` (no flags) scans `./tests` recursively and will attempt to run unit, integration, **and** performance tests in one command, which will fail without the required credentials and variables.

### Verbose Output

```bash
terraform test -test-directory=tests/unit -verbose
```

## Writing Tests

See the [Terraform Testing Guide](../.agents/skills/terraform-testing/SKILL.md) for detailed guidance on writing tests, including mock provider patterns and assertion examples.
