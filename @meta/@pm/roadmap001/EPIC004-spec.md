# EPIC004 Spec: Transactional Database Capabilities

## Purpose

Give a Lua procedure bounded database read/write capabilities while preserving
one checked-out Tursox connection, host-owned transaction, authorization, and
rollback safety.

## Required References

Read `ROADMAP001.md`, `REFERENCES.md` R1/R3 and findings F1/F4, Tursox Pool,
Query, Result, Error, and transaction tests for the selected release.

## Scope

In scope:

- top-level call path through one `Tursox.Pool.transaction/3`
- `db.one`, `db.all`, and `db.exec` Deflua host APIs
- positional/named parameter conversion and safe result conversion
- configurable policy callback receiving caller/procedure/operation metadata
- statement, row, byte, SQL-size, parameter, and deadline budgets
- rollback on Lua, policy, conversion, limit, Tursox, throw, exit, and timeout failures
- affected-row metadata and explicit zero/many-row behavior for `db.one`
- safe database error translation and telemetry metadata

Out of scope:

- nested named procedures
- transaction control or raw connection access from Lua
- claiming raw SQL is tenant-safe without application policy
- automatic retries or savepoints

## Database Contract

All host database calls use the checkout-bound handle in opaque private execution
context. Lua cannot replace it. Scripts cannot invoke transaction statements
through the supported API; policy can further restrict SQL operations/tables.
The outer host commits only after successful Lua completion and valid result
conversion.

`db.one` returns nil for no row and fails on more than one row. `db.all` is
bounded before materializing. Duplicate columns follow an explicit configured
policy rather than silent loss.

## Acceptance Criteria

- Read/compare/write logic commits atomically on success.
- Every failure path rolls back all prior writes.
- Pool size one cannot deadlock from an accidental second checkout.
- Statement/row/byte/deadline budgets are aggregate and enforced before excess transfer.
- Policy denial executes no SQL and exposes no sensitive values.
- Parameterized text/blob/null/number values round-trip correctly.
- Concurrent calls receive isolated connections/transactions and contexts.

## Test Strategy

Cover successful CRUD, conditional updates, constraints, malformed SQL, zero/many
rows, duplicate columns, large results/blobs, transaction text attempts, policy
denials, timeout/kill, pool size one, concurrent callers, and telemetry redaction.
