# EPIC003 Plan: Sandboxed Lua Runtime

## Required Reading

Read `ROADMAP001.md`, `REFERENCES.md`, and `EPIC003-spec.md` completely before
Phase 3.1; inspect exact Deflua source before relying on a limit or value shape.

## Progress

- [ ] Phase 3.1: Define Lua entry, arguments, supported values, returns, failures, and isolation semantics.
- [ ] Phase 3.2: Implement source parsing/compilation and immutable chunk cache identity.
- [ ] Phase 3.3: Build a fresh finite-limit Deflua VM with opaque private execution context per invocation.
- [ ] Phase 3.4: Inject arguments and implement strict bidirectional value conversion.
- [ ] Phase 3.5: Implement `fail`, compile/runtime/conversion errors, and safe source-line attribution.
- [ ] Phase 3.6: Prove sandbox denial, global isolation, cache correctness, and adversarial limits.
- [ ] Phase 3.7: Pass the epic gate and create the focused Epic 3 commit.

## Implementation Steps

1. Freeze the Lua function/chunk return convention and supported data model.
2. Parse once and key cache entries by immutable procedure identity.
3. Create fresh VMs with finite instructions/depth/string settings and private context.
4. Convert args/results without exposing internal Deflua tags or cyclic data.
5. Map failures to redacted stable errors with safe procedure/line metadata.
6. Attack disabled host paths, loops, recursion, allocations, globals, cache races, and concurrency.
7. Run QA and commit the green epic.

## Quality Gate

- [ ] Fresh VM isolation and immutable chunk reuse are proven.
- [ ] Supported values round-trip; unsupported/deep/cyclic values fail safely.
- [ ] All configured Lua limits are finite and deterministic.
- [ ] Filesystem/network/process/environment/module paths remain unavailable.
- [ ] Errors expose no source or data values by default.

## Commit Rule

Commit as `roadmap001 - epic 3 - add sandboxed Lua execution` with VM isolation,
value, cache, sandbox, resource-limit, and QA verification in the body.
