# EPIC002 Spec: Procedure Catalog, Sources, and Immutable Versions

## Purpose

Define how procedures are identified, validated, persisted, resolved, updated,
and addressed without coupling execution to one storage strategy.

## Required References

Read `ROADMAP001.md`, `REFERENCES.md` findings F7/F8, Tursox parameter/result
contracts, and exact Deflua parser error shapes.

## Scope

In scope:

- `%Tursox.Procedures.Procedure{}` and validated names/languages/metadata
- `Tursox.Procedures.Source` behavior
- in-memory source for tests and application-provided definitions
- database catalog schema, explicit install SQL, and source implementation
- create, publish/enable, disable, fetch, list, and immutable version operations
- SHA-256 source identity and canonical source-size limits
- source errors and redacted metadata
- cache-key contract, but not compiled cache implementation

Out of scope:

- automatic application migration execution
- Lua evaluation or database host functions
- destructive in-place mutation of published versions
- tenant authorization policy beyond source callback context plumbing

## Catalog Contract

A resolved procedure has immutable `{name, version, source_hash}` identity.
Publishing changed source creates a new positive version. Disabled versions
cannot be selected for new calls. Historical rows remain available for audit or
explicit administration according to documented retention behavior.

Catalog SQL is parameterized and executes through the caller-provided Tursox
pool/transaction. The package provides explicit installation and inspection;
starting the application never silently creates tables.

## Acceptance Criteria

- Memory and database sources satisfy one shared contract suite.
- Valid source round-trips with stable hash/version identity.
- Concurrent publication allocates deterministic unique versions or returns a
  retryable conflict without duplicate active identity.
- Invalid names, language, source size/encoding, metadata, and hashes fail safely.
- Disabled/missing procedures are distinguished.
- Catalog table names/options are validated and cannot inject SQL identifiers.
- Source structs, errors, logs, and inspection exclude procedure source.

## Test Strategy

Cover Unicode/source boundaries, duplicate publication, concurrent writers,
disable/enable, historical fetch, malformed catalog rows, missing installation,
separate databases, memory-source parity, and clean reopen/persistence.
