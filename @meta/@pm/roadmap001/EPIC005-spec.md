# EPIC005 Spec: Composable Nested Procedures

## Purpose

Allow one stored procedure to invoke another by name while retaining atomicity,
isolation, finite aggregate budgets, and an auditable immutable version trace.

## Required References

Read `ROADMAP001.md`, `REFERENCES.md` findings F2/F5/F6/F7, and completed Epic
2–4 source/transaction/runtime contracts.

## Scope

In scope:

- `procedures.call(name, args)` Lua host API
- internal nested runner that reuses the existing execution context
- fresh Lua VM per child with shared checkout/transaction/budgets
- procedure stack and exact invoked version/hash trace
- call depth, total call count, cycle, argument/result, statement, row, byte, and deadline limits
- strict child failure propagation and permanently failed transaction state
- caller/policy propagation to every child
- nested result conversion and stack-aware safe errors

Out of scope:

- child connection checkout or independent transaction
- catch-and-commit after child failure
- savepoints or partial child rollback
- asynchronous/parallel child calls
- dependency manifests or static linking between procedures

## Composition Contract

The public top-level API is entered once. Child calls invoke the internal runner
directly; they do not call the public service and cannot check out another pool
worker. All calls share one deadline and aggregate counters.

A child error marks context `transaction_failed`. Lua `pcall` may observe a
runtime error, but the host still refuses commit. Cycles are rejected by default;
finite recursion may be a future explicit policy.

## Acceptance Criteria

- A→B→C reads/writes commit in one transaction.
- Failure at any depth rolls back every ancestor/child write.
- Composition works with pool size one and performs no second checkout.
- Cycles, depth, total calls, aggregate statements/rows/bytes, and deadline limits are deterministic.
- Policy cannot be bypassed or elevated by calling another procedure.
- Trace records exact immutable identities in call order without source/arguments/results.
- Concurrent call trees do not share stacks, budgets, or VM globals.

## Test Strategy

Cover deep successful chains, missing/disabled children, direct/indirect cycles,
child compile/runtime/database/policy failures, caught errors, budget exhaustion
across many small children, source update during a tree, pool size one, and
concurrent trees.
