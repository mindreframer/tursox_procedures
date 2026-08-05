# Changelog

## 0.1.0 - 2026-08-05

### Added

- Standalone Tursox companion package with caller-supervised procedure services.
- Immutable in-memory and explicit Tursox-backed procedure catalogs with
  version/hash identity and bounded compiled-chunk caching.
- Pure-Elixir Deflua execution with fresh sandboxed VMs, strict value conversion,
  source-line errors, and finite language/host resource limits.
- Transactional `db.one`, `db.all`, `db.exec`, explicit blob/null values,
  parameter binding, policy authorization, result bounds, and strict rollback.
- Atomic nested `procedures.call` composition on one checkout/transaction with
  cycles, depth/count limits, aggregate budgets, immutable traces, and strict
  child-failure propagation.
- Redacted call, procedure, database, and cache telemetry; timeout/heap process
  isolation; documentation, package QA, and clean-consumer verification.
