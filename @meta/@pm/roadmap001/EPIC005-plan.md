# EPIC005 Plan: Composable Nested Procedures

## Required Reading

Read `ROADMAP001.md`, `REFERENCES.md`, and `EPIC005-spec.md` completely before
Phase 5.1; findings F2, F5, and F6 are binding.

## Progress

- [ ] Phase 5.1: Define child resolution, stack, version trace, strict failure, cycle, and budget semantics.
- [ ] Phase 5.2: Implement `procedures.call` through the internal runner and existing execution context.
- [ ] Phase 5.3: Reuse the exact parent checkout/transaction while creating an isolated child Lua VM.
- [ ] Phase 5.4: Propagate caller/policy and record exact immutable identities for the complete call tree.
- [ ] Phase 5.5: Enforce cycles, depth, total calls, deadline, statements, rows, bytes, and result budgets across children.
- [ ] Phase 5.6: Prove strict rollback after every child failure, including Lua-caught failures and pool size one.
- [ ] Phase 5.7: Pass the epic gate and create the focused Epic 5 commit.

## Implementation Steps

1. Add safe stack/trace structures and aggregate counters to execution context.
2. Expose one host call that invokes the internal runner, never the public service.
3. Resolve/compile/run each child in a fresh VM while sharing checkout and budget state.
4. Re-authorize each child/capability and append immutable version/hash trace entries.
5. Reject direct/indirect cycles and all aggregate resource-limit violations deterministically.
6. Test successful/failing/deep/concurrent/update-during-call trees and caught child errors.
7. Run QA and commit the green epic.

## Quality Gate

- [ ] Nested writes are atomic with the outer call.
- [ ] Pool size one composition performs no second checkout/deadlock.
- [ ] Any child failure prevents commit even when Lua catches its error.
- [ ] Cycles/depth/count and aggregate budgets are enforced.
- [ ] Policy and execution context cannot be escalated or leaked.

## Commit Rule

Commit as `roadmap001 - epic 5 - add atomic procedure composition` with nested
transaction, failure, cycle, budget, trace, and QA verification in the body.
