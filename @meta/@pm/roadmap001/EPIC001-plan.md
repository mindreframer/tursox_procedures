# EPIC001 Plan: Package Foundation and Executable Contracts

## Required Reading

Read `AGENTS.md`, `ROADMAP001.md`, `REFERENCES.md`, and `EPIC001-spec.md`
completely before Phase 1.1.

## Progress

- [ ] Phase 1.1: Freeze package boundaries, public names, non-goals, and dependency direction.
- [ ] Phase 1.2: Verify and lock compatible published Tursox, Deflua, DBConnection, and tooling versions.
- [ ] Phase 1.3: Define redacted procedure, result, error, limits, policy, source, and execution-context contracts.
- [ ] Phase 1.4: Add exact Tursox checkout/transaction and result-shape capability probes.
- [ ] Phase 1.5: Add exact Deflua parse/VM/private-state/host-API/limit capability probes.
- [ ] Phase 1.6: Finalize test support, docs/package checks, clean CI, and compatibility record.
- [ ] Phase 1.7: Pass the epic gate and create the focused Epic 1 commit.

## Implementation Steps

1. Replace scaffold-only concepts with module contracts and stable types, without procedure execution.
2. Resolve dependencies from Hex, commit `mix.lock`, and record exact sources/checksums/APIs.
3. Implement only validation/redaction skeletons needed by later epics.
4. Prove one checkout-bound Tursox transaction and safe query/result access.
5. Prove isolated Deflua state, private context, host API, parsing, and finite limits.
6. Extend QA and CI with package-content and clean capability tests.
7. Run `bin/qa_check.sh`, inspect the diff/package, and commit the green epic.

## Quality Gate

- [ ] All dependencies are exact/compatible and Hex-resolvable.
- [ ] Tursox/Deflua capability probes pass.
- [ ] Public skeletons leak no sensitive/internal state.
- [ ] Docs and package build warning-free.
- [ ] No procedure behavior exists.

## Commit Rule

Commit as `roadmap001 - epic 1 - establish procedure package contracts` with
dependency, capability, package, and QA verification in the body.
