# EPIC006 Plan: Supervision, Policy, Cache, and Observability

## Required Reading

Read `ROADMAP001.md`, `REFERENCES.md`, and `EPIC006-spec.md` completely before
Phase 6.1.

## Progress

- [ ] Phase 6.1: Define caller-owned supervision, naming, configuration, shutdown, and call-process contracts.
- [ ] Phase 6.2: Implement pid/name-addressed services with no global singleton or dynamic atoms.
- [ ] Phase 6.3: Add bounded compiled cache ownership, concurrent compile control, eviction, and refresh behavior.
- [ ] Phase 6.4: Complete policy hooks and caller/procedure/capability context propagation.
- [ ] Phase 6.5: Add supervised deadlines/heap policy, rollback cleanup, telemetry, and redacted status.
- [ ] Phase 6.6: Stress multiple services, concurrency, updates, cache churn, failures, and shutdown races.
- [ ] Phase 6.7: Pass the epic gate and create the focused Epic 6 commit.

## Implementation Steps

1. Add an optional supervised service configured with one pool/source/limits/policy set.
2. Keep names caller-controlled and avoid module-global state/dynamic atoms.
3. Bound immutable cache entries and prevent duplicate concurrent compilation for one identity.
4. Invoke policy with safe immutable context at each child and database boundary.
5. Run calls in supervised processes with timeout/heap cleanup and emit redacted telemetry.
6. Test independent services, stampedes, eviction, source churn, kills, and shutdown under load.
7. Run QA and commit the green epic.

## Quality Gate

- [ ] Multiple services remain isolated and require explicit startup.
- [ ] Cache size/concurrency/eviction are bounded and correctness-neutral.
- [ ] Timeout/heap failures roll back and service/pool recover.
- [ ] Policy sees every relevant boundary.
- [ ] Telemetry/status contain no procedure or database values.

## Commit Rule

Commit as `roadmap001 - epic 6 - add supervised procedure runtime` with service,
cache, policy, process-limit, observability, stress, and QA verification.
