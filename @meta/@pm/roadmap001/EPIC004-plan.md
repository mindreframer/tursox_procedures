# EPIC004 Plan: Transactional Database Capabilities

## Required Reading

Read `ROADMAP001.md`, `REFERENCES.md`, and `EPIC004-spec.md` completely before
Phase 4.1; use only exact public Tursox APIs verified in Epic 1.

## Progress

- [x] Phase 4.1: Define top-level call, checkout ownership, transaction mode, policy, and aggregate budget contracts.
- [x] Phase 4.2: Implement one host-owned Tursox transaction and opaque checkout-bound execution context.
- [x] Phase 4.3: Implement authorized, parameterized, bounded `db.one` and `db.all`.
- [x] Phase 4.4: Implement authorized `db.exec` with affected-row metadata and transaction-control rejection.
- [x] Phase 4.5: Enforce statement/row/byte/deadline/result budgets and safe database error mapping.
- [x] Phase 4.6: Prove commit/rollback, pool-size-one behavior, concurrency isolation, limits, and redaction.
- [x] Phase 4.7: Pass the epic gate and create the focused Epic 4 commit.

## Implementation Steps

1. Add the public top-level call around `Tursox.Pool.transaction/3` and one mutable host budget context.
2. Store only an opaque checkout-bound handle in Deflua private state.
3. Implement read capabilities with explicit zero/many/duplicate-column semantics.
4. Implement write capability, deny transaction-control statements, and invoke policy before execution.
5. Charge aggregate budgets before/while transferring database values and honor one deadline.
6. Test every commit/rollback/failure path, pool size one, concurrent calls, and sensitive-value capture.
7. Run QA and commit the green epic.

## Quality Gate

- [x] Successful procedure writes commit atomically.
- [x] Every failure rolls back all prior writes.
- [x] No database operation checks out a second connection.
- [x] Policy and aggregate resource limits cannot be bypassed.
- [x] Database errors/telemetry are redacted.

## Commit Rule

Commit as `roadmap001 - epic 4 - add transactional database capabilities` with
CRUD, rollback, pool, policy, budget, and QA verification in the body.
