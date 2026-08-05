# EPIC001 Spec: Package Foundation and Executable Contracts

## Purpose

Turn the scaffold into a reproducible companion-package foundation and prove the
exact Tursox/Deflua APIs before procedure behavior is implemented.

## Required References

Read `ROADMAP001.md`, `REFERENCES.md`, exact Tursox release source, Deflua 1.0.2
source/docs, and DBConnection's version-matched transaction contract.

## Scope

In scope:

- public namespace and module boundary for service, procedure, source, runner,
  policy, error, limits, execution context, and Lua/database APIs
- exact compatible published dependency pins and committed `mix.lock`
- stable option, result, and error-shape design
- package metadata, docs skeleton, CI, test support, and authoritative QA
- versioned compatibility/capability report with compile/runtime probes
- explicit security, redaction, transaction, and non-goal decisions

Out of scope:

- procedure catalog, Lua evaluation, database capabilities, nested execution, or caching
- claiming a production sandbox
- package publication

## Foundation Contract

The package is pure Elixir and depends on Tursox through a published public API.
No sibling path, native extension, Turso internals, or process-global default
service is introduced. Public structs never expose pool worker internals or Lua
VM implementation tags.

QA is deterministic from repository root and stores stage logs under
`_build/qa/latest`. The capability record separates source-proven APIs from
behavior verified by executable probes.

## Acceptance Criteria

- Locked dependencies resolve from Hex in a clean checkout.
- Package namespace and planned public contracts compile warning-free.
- Exact Tursox checkout-bound transaction behavior is proven by a minimal test.
- Exact Deflua parsing, isolated VM, private state, host API, and limit behavior
  is proven without yet exposing procedures.
- Errors and inspections are redacted by construction.
- CI runs `bin/qa_check.sh`; docs and Hex package build cleanly.
- No user procedure can execute yet.

## Test Strategy

Use compile-time contract tests, dependency/capability probes, package-content
inspection, clean temporary databases, and tests proving that public structs do
not leak source, arguments, rows, connections, or VM state.
