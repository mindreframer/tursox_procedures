# EPIC006 Spec: Supervision, Policy, Cache, and Observability

## Purpose

Provide a caller-supervised runtime with predictable cache/source lifecycle,
concurrent isolation, authorization hooks, and redacted operational visibility.

## Required References

Read `ROADMAP001.md`, `REFERENCES.md` R4 and findings F4/F6/F7, and all completed
runtime/source/composition contracts.

## Scope

In scope:

- `Tursox.Procedures` child specification and caller-selected pid/name
- validated service configuration and no mandatory global singleton
- owned compiled-chunk cache with capacity and deterministic eviction
- source adapter lifecycle and optional safe invalidation/refresh API
- policy behavior and minimal allow/deny helpers without pretending to parse all SQL
- per-call supervised isolation, host timeout, and heap policy
- telemetry for calls, nested calls, compilation/cache, database operations, limits, and outcomes
- redacted metadata/status and graceful service shutdown
- multiple independent services and databases in one VM

Out of scope:

- distributed cache or cross-node procedure execution
- authentication/UI/control-plane implementation
- dynamic atoms from service/procedure/tenant identifiers
- logging procedure source, arguments, SQL parameters, or rows

## Service Contract

Applications explicitly start one or more procedure services. Each service owns
configuration/cache only; database resources remain governed by the configured
Tursox pool. Calls run in isolated supervised processes so a timeout or heap
failure does not corrupt service state, and transaction cleanup is verified.

Cache entries are immutable and bounded. Eviction affects performance only,
never correctness. Multiple services may use overlapping procedure names
without configuration, cache, caller, or telemetry leakage.

## Acceptance Criteria

- Named and pid-addressed services support concurrent calls and clean shutdown.
- Timeout/heap exits roll back and leave the service/pool usable.
- Cache capacity/eviction/concurrent compile behavior is deterministic and bounded.
- Source updates become visible under the documented consistency policy.
- Policy receives immutable safe context on every database and child call.
- Telemetry includes durations/counts/classes/identities but no source/data/secrets.
- No dynamic atoms or global service are introduced.

## Test Strategy

Exercise multiple services, high concurrency, compile stampedes, cache eviction,
source updates, process kills, deadline/heap failures, pool/service shutdown races,
policy state, telemetry capture/redaction, and repeated start/stop cleanup.
