# EPIC002 Plan: Procedure Catalog, Sources, and Immutable Versions

## Required Reading

Read `ROADMAP001.md`, `REFERENCES.md`, and `EPIC002-spec.md` completely before
Phase 2.1.

## Progress

- [x] Phase 2.1: Define validated procedure identity, metadata, language, version, and source-hash contracts.
- [x] Phase 2.2: Implement the source behavior and deterministic in-memory source.
- [x] Phase 2.3: Design explicit catalog installation SQL and validated configuration.
- [x] Phase 2.4: Implement database-backed fetch/list/history and shared source contract tests.
- [x] Phase 2.5: Implement immutable publish, enable, disable, and concurrent version allocation.
- [x] Phase 2.6: Harden source size/encoding, malformed rows, persistence, isolation, and redaction.
- [x] Phase 2.7: Pass the epic gate and create the focused Epic 2 commit.

## Implementation Steps

1. Add `%Procedure{}` with opaque/redacted inspection and canonical SHA-256 identity.
2. Build one source behavior exercised identically by memory/database adapters.
3. Provide installation SQL/helpers without automatic startup migrations.
4. Implement parameterized catalog reads with explicit missing/disabled outcomes.
5. Publish new immutable versions transactionally; never mutate published source in place.
6. Test races, reopen, malformed data, Unicode/size boundaries, and separate databases.
7. Run QA, inspect package contents, and commit the green epic.

## Quality Gate

- [x] Memory/database adapters pass one contract suite.
- [x] Version/hash identity is immutable and deterministic.
- [x] Concurrent publication cannot create duplicate versions.
- [x] Catalog installation is explicit and injection-safe.
- [x] Source never leaks through inspect/errors/telemetry.

## Commit Rule

Commit as `roadmap001 - epic 2 - add immutable procedure sources` with catalog,
version race, persistence, redaction, and QA verification in the body.
