# EPIC003 Spec: Sandboxed Lua Runtime

## Purpose

Compile and execute one resolved Lua procedure in an isolated Deflua VM with a
small stable value/error contract and deterministic language limits.

## Required References

Read `ROADMAP001.md`, `REFERENCES.md` R2/R5 and findings F3/F6, plus Deflua
1.0.2 source for parsing, chunks, private state, host APIs, and limits.

## Scope

In scope:

- exact `lua` integration and a fresh VM per procedure invocation
- immutable compiled `Lua.Chunk` cache keyed by procedure identity
- `args` injection and supported Elixir/Lua value conversion
- `fail(code, message)` and structured return/error conversion
- private opaque execution context unavailable to Lua
- finite instructions, Lua call depth, string/source/input/output bounds
- source name/line attribution and redacted stack formatting
- proof that filesystem/network/process/environment/module loading stays disabled

Out of scope:

- database functions
- nested named procedures
- shared mutable Lua globals between calls
- arbitrary Elixir module/function access
- compatibility with every Lua 5.3 feature Deflua intentionally omits

## Runtime Contract

Each invocation gets a new Lua VM and fresh globals. A compiled chunk may be
reused, but runtime state never is. Only documented scalars, lists, and maps
cross the boundary. Cyclic/sparse/unsupported Lua values and excessive nesting
return stable conversion errors.

Deflua limits are set explicitly; defaults of `:infinity` are forbidden. A host
supervision deadline and heap policy remain required in later epics because
language limits alone are not a complete resource boundary.

## Acceptance Criteria

- Procedures receive immutable decoded arguments and return supported values.
- Syntax/runtime/user failures preserve safe procedure and line attribution.
- Global mutation cannot leak to another invocation.
- Cache hits execute the correct immutable source identity.
- Instruction, depth, source, string, argument, and result limits are deterministic.
- Sandboxed host paths fail and no unregistered Elixir function is callable.
- Source and data values do not appear in standard errors/telemetry.

## Test Strategy

Cover every supported value, malformed and adversarial source, infinite loops,
recursion, allocation bombs, giant/deep/cyclic tables, `pcall`, global leakage,
cache identity races, concurrent VMs, and attempted access to every disabled API.
