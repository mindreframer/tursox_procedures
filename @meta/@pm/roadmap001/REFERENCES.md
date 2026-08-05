# ROADMAP001 Reference Guide

## 1. Required Use

Before implementation, read in order:

1. repository-root `AGENTS.md`;
2. `@meta/@pm/ROADMAP001.md`;
3. this file;
4. all seven epic specs and plans; and
5. exact-version dependency source relevant to the active phase.

Sibling checkouts are read-only conveniences, never package dependencies.
Committed `mix.exs` and lockfiles must resolve without local paths.

## 2. Source Authority

When sources disagree, use this precedence:

1. ROADMAP001 and accepted project decisions define intended behavior.
2. Exact dependency source resolved by `mix.lock` defines available APIs.
3. Exact-version HexDocs explain those APIs; source and executable tests win.
4. Upstream main branches are forward context only.
5. README examples and sibling projects are structural guidance, not proof.

Never close an acceptance criterion from unversioned `latest` documentation.

## 3. Reference Catalog

### R0 — This repository

- Repository: <https://github.com/mindreframer/tursox_procedures>
- Root contains `mix.exs`, `lib/`, `test/`, `bin/qa_check.sh`, and this roadmap.
- Resolve every path from repository root; never commit the planning machine's absolute path.

### R1 — Tursox public database API

- Repository: <https://github.com/mindreframer/tursox>
- Baseline release: `v0.2.1`
- Release commit: `6ae70348a9c736cf3595120aa73e77cc78fc447d`
- Relevant public modules: `Tursox.Pool`, `Tursox.Query`, `Tursox.Result`,
  `Tursox.Error`, and transaction behavior exposed through `Tursox.Pool.transaction/3`.
- Relevant source files at the release tag:
  - `lib/tursox/pool.ex`
  - `lib/tursox/pool/connection.ex`
  - `lib/tursox/query.ex`
  - `lib/tursox/result.ex`
  - `lib/tursox/transaction.ex`

Tursox Procedures must use public APIs only. Epic 1 must verify the first
compatible Tursox release available from Hex before adding a publishable
dependency. Git/path dependencies may be used only as temporary local research
and must not enter a package release.

### R2 — Deflua `lua` package

- Hex package: `lua`
- Baseline version: `1.0.2`
- Hex checksum: `cf14ab77c27f1acf2fb933b82530bd728dab8a69e7a05757e21a3b49180d4690`
- Source tag/commit: `v1.0.2`, `3f2aead2596dfabe0c58415235d766cd70574f53`
- Repository: <https://github.com/tv-labs/lua>
- Versioned docs: <https://hexdocs.pm/lua/1.0.2/Lua.html>
- API docs: <https://hexdocs.pm/lua/1.0.2/Lua.API.html>

Relevant APIs to verify from exact source include `Lua.new/1`, `Lua.parse_chunk/1`,
`Lua.eval!/3`, `Lua.load_api/3`, private state, `Lua.API.deflua`,
`max_instructions`, `max_call_depth`, and `max_string_bytes`.

Deflua defaults are not the product policy. In particular, infinity defaults
must be replaced with finite package limits and dangerous sandbox exclusions
must never be enabled by procedure source.

### R3 — DBConnection transaction semantics

Tursox currently resolves DBConnection `2.10.2`. Consult exact source/docs for
checkout-bound transaction callbacks and rollback return shapes:

- <https://hexdocs.pm/db_connection/2.10.2/DBConnection.html>
- <https://github.com/elixir-ecto/db_connection>

Use this reference through Tursox's public wrapper; do not couple package code
to Tursox private pool internals.

### R4 — Elixir process isolation and telemetry

Use version-matched Elixir/OTP documentation for supervised tasks, monitors,
process heap policy, exits, and timeouts. Use exact-version Telemetry docs when
that dependency is introduced. A Lua instruction budget does not replace a
host deadline or heap bound.

### R5 — Lua 5.3 language semantics

- Reference manual: <https://www.lua.org/manual/5.3/manual.html>

Use it for language semantics only. Deflua 1.0.2's implemented subset and
explicit non-goals are authoritative for runtime behavior.

### R6 — Tursox repository conventions

The sibling Tursox repository supplies roadmap, package metadata, QA log, CI,
documentation, security, and release conventions. Copy no native build or
precompiled-NIF machinery into this pure-Elixir package.

## 4. Encoded Findings

### F1 — Existing Tursox transaction boundary is sufficient

`Tursox.Pool.transaction/3` yields a checkout-bound DBConnection handle. Calls
through that handle stay on one pool worker. A top-level procedure runner can
therefore own one transaction, and nested runners can reuse the same handle
without changes to Turso or native runtime extensions.

### F2 — Nested runners must not call the public top-level entry recursively

A nested `procedures.call` must invoke an internal runner with the existing
execution context. Calling the top-level API again would check out another
connection and create an independent transaction, violating atomic composition
and risking pool deadlock.

### F3 — Deflua matches the isolation model

Deflua 1.0.2 is pure Elixir, uses immutable VM state, exposes host functions
through `Lua.API`, supports opaque private state, compiles reusable chunks, and
provides instruction/call-depth/string bounds. Fresh VMs per procedure are
therefore practical without a native extension.

### F4 — Language sandboxing is not authorization

Blocking filesystem/network/process APIs does not constrain an exposed raw SQL
function. A procedure with unrestricted `db.exec` has the checked-out
connection's database authority. Every database call must pass a package policy
hook, and documentation must distinguish trusted-raw-SQL from restricted modes.

### F5 — Strict nested failure is the smallest safe initial contract

Without a separately verified savepoint around every child call, catching a
nested failure could retain the child's earlier writes. ROADMAP001 therefore
marks the entire top-level transaction failed after any child failure. Savepoint
recovery is deferred.

### F6 — Per-evaluation limits are not aggregate call-tree limits

A fresh Lua VM resets Deflua's evaluation budgets. The package must additionally
track one host deadline, total nested calls, total statements, total rows, and
total returned bytes across the complete call tree.

### F7 — Immutable cache identity avoids invalidation races

Compiled chunks are keyed by `{name, version, source_hash}`. Source updates
create new identities rather than mutating an entry. Existing calls can finish
with resolved versions while later calls select the replacement.

### F8 — Publishable dependencies must exist on Hex

Hex packages cannot rely on sibling paths or ordinary git dependencies. Epic 1
must resolve compatible published Tursox and `lua` versions before locking the
runtime graph; Epic 7 must compile an unpacked package in a clean consumer.

## 5. Required Epic 1 Capability Record

Before Epic 1 closes, add `docs/compatibility.md` recording:

- exact Elixir, OTP, Tursox, DBConnection, `lua`, and ExDoc resolutions;
- package and source hashes where available;
- exact Tursox transaction/query/result APIs used;
- exact Deflua compiler, VM, private-state, conversion, sandbox, and limit APIs used;
- behavior experimentally verified rather than inferred;
- absent capabilities and deferred semantics; and
- links to exact source/docs with verification date.
