# Changelog

## 0.2.0

- Replace tenant-wide DLP policy detail reads with a single policy-index request and targeted detail requests for uniquely matched requested names.
- Preserve scalar and batch output projections, generated `.tfvars` structure, and connector-rule behavior.
- Fail closed for paginated or malformed API responses and when a detail response does not match the requested policy.
- Add configurable Business API host and OAuth scope inputs, synthetic response tests, provider-version coverage, and a baseline-versus-candidate benchmark.
