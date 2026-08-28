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
| `performance/scalar/` | Scalar benchmark (opt-in) | OIDC required | `command = apply` |
| `performance/batch/` | Batch benchmark (opt-in) | OIDC required | `command = apply` |

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

### Performance Benchmarks (opt-in)

Performance tests are isolated under `tests/performance/` and must be invoked explicitly by passing their directory to `-test-directory`. `make test-unit` targets `tests/unit` and `make test-integration` targets `tests/integration`, so neither picks up `tests/performance/`. Bare `terraform test` without a `-test-directory` flag scans `./tests` recursively and **would** include performance tests, which is another reason to always use the explicit `make` targets or an explicit `-test-directory` flag for controlled test runs.

#### Prerequisites

- OIDC credentials (same as integration tests above)
- Two existing DLP policy display names:
  - `TF_VAR_source_policy_name` / `TF_VAR_source_policy_name_a` — Policy A
  - `TF_VAR_source_policy_name_b` — Policy B

#### Scalar benchmark (one policy at a time)

```bash
export POWER_PLATFORM_USE_OIDC=true
export POWER_PLATFORM_TENANT_ID=<your-tenant-id>
export POWER_PLATFORM_CLIENT_ID=<your-client-id>
export TF_VAR_source_policy_name=<policy-A-display-name>

terraform init -backend=false
time terraform test -test-directory=tests/performance/scalar

# Repeat for policy B
export TF_VAR_source_policy_name=<policy-B-display-name>
time terraform test -test-directory=tests/performance/scalar
```

#### Batch benchmark (both policies in one invocation)

```bash
export POWER_PLATFORM_USE_OIDC=true
export POWER_PLATFORM_TENANT_ID=<your-tenant-id>
export POWER_PLATFORM_CLIENT_ID=<your-client-id>
export TF_VAR_source_policy_name_a=<policy-A-display-name>
export TF_VAR_source_policy_name_b=<policy-B-display-name>

terraform init -backend=false
time terraform test -test-directory=tests/performance/batch
```

#### CI behaviour

The benchmark job in `.github/workflows/ci.yml` runs only when **all four** of the following repository variables are configured:

- `ENABLE_INTEGRATION_TESTS` set to `'true'`
- `ENABLE_INTEGRATION_PERFORMANCE_TESTS` set to `'true'`
- `INTEGRATION_SOURCE_POLICY_NAME` set to a non-empty policy display name (Policy A)
- `INTEGRATION_SOURCE_POLICY_NAME_B` set to a non-empty policy display name (Policy B)

This prevents an enabled-but-unconfigured benchmark job from failing due to unset policy-name variables.

It runs three cold Terraform invocations (scalar A, scalar B, batch A+B), times each one in milliseconds using nanosecond-resolution `date +%s%N`, and prints a machine-readable summary to the job log and GitHub Step Summary. **No absolute threshold is enforced** — the job fails only if a correctness assertion inside the test fails, not based on elapsed time.

> [!NOTE]
> Both benchmark test files use `command = apply` rather than `command = plan`. The module calls `timestamp()` inside locals, which leaves outputs such as `generated_tfvars_content` unknown during a plan-only run, causing Terraform to report `Unknown condition value` on the non-empty content assertions. Apply resolves all outputs so the assertions can be evaluated. Tests are isolated: Terraform destroys any resources it creates when the run completes, and the exporter writes only local files that are cleaned up automatically.

#### Interpretation caveat

> [!NOTE]
> These benchmarks measure **Terraform-level wall-clock time** — the total elapsed time as seen by the Terraform CLI, including provider initialisation, API round-trips, and local computation. They do **not** measure HTTP request counts or provider-internal behaviour.
>
> To draw a meaningful scalar vs. batch comparison, always compare the **scalar A + scalar B combined total** against the **batch A+B elapsed time** from the **same CI run** (same runner, tenant, and time window). Results from different runs, tenants, or times are not directly comparable.

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
