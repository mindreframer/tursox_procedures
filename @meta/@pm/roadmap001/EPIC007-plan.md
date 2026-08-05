# EPIC007 Plan: Hardening, Documentation, and Initial Release

## Required Reading

Read all ROADMAP001 files and `EPIC007-spec.md` completely before Phase 7.1;
inspect exact dependency licenses and current Hex/GitHub release guidance.

## Progress

- [x] Phase 7.1: Stabilize public names, options, errors, results, compatibility, and security claims.
- [x] Phase 7.2: Add adversarial sandbox/authorization/resource/concurrency/fault and fuzz coverage.
- [x] Phase 7.3: Complete executable README, catalog, Lua API, composition, policy, limits, and operations guides.
- [x] Phase 7.4: Audit telemetry/errors/inspection, package contents, licenses/notices, and dependency graph.
- [x] Phase 7.5: Add clean unpacked-package consumer and final CI/release automation.
- [x] Phase 7.6: Synchronize `0.1.0`, changelog/docs/examples, and verify a clean Hex-resolvable install.
- [ ] Phase 7.7: Pass final QA, publish GitHub/Hex/HexDocs, monitor verification, and create the focused Epic 7 commit.

## Implementation Steps

1. Freeze the initial API after source/runtime/database/composition/service consistency review.
2. Attack sandbox, policy, limits, deep data, malformed source, races, and lifecycle paths.
3. Test every documented example and clearly distinguish sandbox from database authorization.
4. Inspect dependency licenses, redaction, package tarball, and absence of local paths/generated secrets.
5. Compile/test an unpacked package in a clean consumer using Hex dependencies only.
6. Synchronize release metadata and run full QA from a clean checkout.
7. Commit/release only when GitHub, Hex, HexDocs, package contents, and final CI are verified.

## Quality Gate

- [ ] Public API/security review is complete.
- [ ] Adversarial, stress, fault, and redaction suites pass.
- [ ] Docs examples execute and package contents are exact.
- [ ] Clean consumer uses no sibling/git/path dependency.
- [ ] Version/changelog/tag/package agree and all publications are verified.

## Commit Rule

Commit as `roadmap001 - epic 7 - release Tursox Procedures 0.1.0` with API,
security, QA, package, consumer, publication, and CI verification in the body.
