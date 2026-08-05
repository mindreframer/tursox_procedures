# ROADMAP001 — Tursox Procedures: Sandboxed Transactional Lua

- **Status:** Complete — released as `0.1.0`
- **Target:** `0.1.0`
- **Primary interface:** Elixir
- **Procedure language:** Lua 5.3 through the pure-Elixir `lua` package
- **Database baseline:** Tursox `0.2.1` or the first compatible published Hex release
- **Required execution reference:** `@meta/@pm/roadmap001/REFERENCES.md`

## 1. Goal

Build a standalone Tursox companion package that lets applications execute
user-defined, versioned Lua procedures by name. Procedure source may live in the
database or an application-provided source, but execution remains above Turso:
one checked-out Tursox connection and one host-owned transaction cover the
complete top-level and nested procedure call tree.

The first release must provide useful data-oriented business logic without
becoming a general server or database-language project. Lua receives only
bounded database and composition capabilities. Filesystem, network, process,
environment, module loading, and transaction-control capabilities remain
unavailable.

## 2. Product Boundary

Tursox Procedures is a separate Hex package and repository:

```text
Application
    └── Tursox.Procedures
          ├── procedure source and compiled-chunk cache
          ├── isolated Lua execution
          └── Tursox public pool/transaction/query APIs
```

Tursox remains the low-level database driver. This package does not modify
Turso, load Lua into the native engine, or require Turso runtime extensions.
Any generic Tursox primitive found missing must be proposed and tested in
Tursox independently; procedure-specific policy stays here.

## 3. Core Execution Contract

A top-level call has the intended form:

```elixir
Tursox.Procedures.call(MyProcedures, "approve_order", arguments,
  caller: current_user
)
```

The runtime must:

1. validate the name, arguments, caller context, and configured limits;
2. check out one Tursox pool connection and begin the configured transaction;
3. resolve an immutable procedure version and source hash;
4. compile or retrieve a cached `Lua.Chunk`;
5. execute it in a fresh sandboxed Lua VM;
6. expose only authorized `db`, `procedures`, and `fail` capabilities;
7. execute nested procedures on the same connection and transaction;
8. commit only when the complete call tree succeeds; and
9. roll back on every database, Lua, authorization, resource, timeout, or nested-call failure.

## 4. Initial Lua Surface

The initial language surface is deliberately small:

```text
args
db.one(sql, params)
db.all(sql, params)
db.exec(sql, params)
procedures.call(name, args)
fail(code, message)
```

Results are limited to documented null/boolean/number/string/list/map values.
Database rows preserve column order or use an explicit duplicate-column policy;
no implicit lossy map conversion is allowed.

Scripts cannot begin, commit, roll back, load files/modules, access the network,
read environment variables, spawn processes, or call arbitrary Elixir modules.

## 5. Composition Contract

Nested procedure calls are synchronous and share the parent's execution
context. They never check out another pool worker and never begin an independent
transaction. Every invoked `{name, version, source_hash}` is recorded.

The initial release is strict:

- any nested failure makes the top-level transaction uncommittable;
- catching a Lua error cannot restore commit eligibility;
- call depth and total call count are finite;
- cycles are rejected by default;
- recoverable nested failures/savepoints are deferred.

## 6. Source and Version Contract

A source returns an immutable procedure record containing at least:

```text
name, language, source, version, source_hash, enabled, metadata
```

ROADMAP001 ships database and in-memory sources. Database-backed source rows are
resolved through the same checked-out transaction where practical. The compiled
cache is keyed by immutable identity, never only by procedure name. Updating a
procedure creates a new version/hash; running calls continue with the versions
they already resolved.

The package must not silently create or migrate application tables. It may
provide explicit install SQL and catalog helpers whose execution is caller
controlled.

## 7. Authorization and Security Contract

Deflua's language sandbox is not database authorization. Every host capability
must receive the caller, current procedure identity, limits, and one opaque
execution context. Applications can choose trusted raw parameterized SQL or a
stricter policy that rejects statements/tables/operations.

Mandatory limits include:

- Lua instruction count and call depth;
- host wall-clock deadline;
- BEAM process heap policy;
- nested procedure depth and total calls;
- database statement count;
- input, source, parameter, row, result, and error sizes;
- rows per query and total rows per call tree.

Procedure source, SQL parameters, returned rows, caller secrets, and database
contents never enter default logs, exceptions, telemetry, or inspection output.

## 8. Error Contract

`Tursox.Procedures.Error` must preserve stable classes such as:

- `:not_found`
- `:disabled`
- `:invalid_argument`
- `:compile_error`
- `:runtime_error`
- `:authorization`
- `:database`
- `:resource_limit`
- `:timeout`
- `:call_cycle`
- `:call_depth`
- `:transaction_failed`
- `:internal`

Errors include safe procedure name/version, source line where available, and a
redacted procedure stack. Raw source and data values are excluded by default.

## 9. In Scope

- reproducible pure-Elixir package foundation and QA;
- exact compatible Tursox and `lua` dependency pins;
- procedure structs, source behaviour, database and memory sources;
- explicit catalog installation and administration helpers;
- isolated Deflua compilation/execution and immutable chunk caching;
- bounded `db.one`, `db.all`, and `db.exec` host capabilities;
- one checked-out transaction for top-level and nested calls;
- strict nested composition, cycle/depth limits, and version traces;
- caller-provided authorization/policy callbacks;
- supervision, cache ownership, telemetry, docs, and initial Hex release.

## 10. Explicitly Deferred

- changes to Turso or Tursox's native engine;
- SQL `CREATE PROCEDURE` or `CALL` syntax;
- direct procedure invocation from arbitrary SQL clients;
- QuickJS or a generic multi-language framework;
- filesystem, network, process, environment, or host module capabilities;
- recoverable nested calls/savepoint semantics;
- distributed transactions or a distributed compiled cache;
- automatic catalog migrations;
- triggers, schedules, queues, HTTP endpoints, authentication, or a control plane;
- claiming database authorization when unrestricted raw SQL is configured.

## 11. Quality Policy

`bin/qa_check.sh` is the authoritative repository gate. It must retain locked
dependency verification, formatting, warning-free compilation, deterministic
ExUnit, warning-free docs, and Hex package construction. Roadmap epics extend it
with clean-consumer, sandbox, transaction, composition, concurrency, fuzz, and
resource-limit coverage.

After every epic:

1. run `bin/qa_check.sh`;
2. fix every failure;
3. verify all phase and epic acceptance criteria;
4. review package contents, secrets, and unrelated changes;
5. check boxes only after evidence exists; and
6. commit as `roadmap001 - epic N - <outcome>`.

## 12. Epics

### Epic 1 — Package Foundation and Executable Contracts

Lock the public boundary, dependency baseline, QA, error skeleton, and
version-matched capability record without implementing procedure behavior.

### Epic 2 — Procedure Catalog, Sources, and Immutable Versions

Implement procedure identity, source resolution, explicit database catalog
installation/administration, memory source, source validation, and cache keys.

### Epic 3 — Sandboxed Lua Runtime

Integrate Deflua with fresh VMs, strict value conversion, compile caching,
private execution context, failures, and deterministic language limits.

### Epic 4 — Transactional Database Capabilities

Expose bounded and authorized query/execute primitives on one checked-out
Tursox transaction and prove rollback, consistency, row bounds, and redaction.

### Epic 5 — Composable Nested Procedures

Implement same-transaction nested calls, stack/version tracing, strict failure
propagation, cycles, call-depth/count limits, and aggregate budgets.

### Epic 6 — Supervision, Policy, Cache, and Observability

Add the caller-supervised service, policy hooks, cache lifecycle, concurrent
call isolation, update behavior, telemetry, and operational metadata.

### Epic 7 — Hardening, Documentation, and Initial Release

Complete stress/security/consumer tests, guides, package contents, synchronized
versioning, GitHub/Hex/HexDocs publication, and release verification.

## 13. Dependency Order

```text
Epic 1: package contracts + QA
   ↓
Epic 2: procedure sources + versions
   ↓
Epic 3: sandboxed Lua runtime
   ↓
Epic 4: transactional DB capabilities
   ↓
Epic 5: nested composition
   ↓
Epic 6: supervision + policy + observability
   ↓
Epic 7: hardening + release
```

## 14. Definition of Initial Success

Version `0.1.0` is successful when an application can install and version Lua
procedures, call one by name through a supervised runtime, safely read and write
through one Tursox transaction, compose procedures atomically, enforce caller
policy and finite resource limits, inspect redacted telemetry, and install the
package from Hex with all documented examples and CI green.
