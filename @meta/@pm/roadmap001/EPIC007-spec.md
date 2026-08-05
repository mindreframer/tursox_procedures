# EPIC007 Spec: Hardening, Documentation, and Initial Release

## Purpose

Stabilize the procedure/source/runtime/policy APIs and release `0.1.0` as a
verified standalone Hex package that feels native to the Tursox ecosystem.

## Required References

Read all roadmap files, exact locked dependency licenses/docs, Hex package and
HexDocs publication guidance, and Tursox's release/QA conventions.

## Scope

In scope:

- public API/options/errors/result compatibility review
- adversarial sandbox, authorization, resource, concurrency, lifecycle, and fuzz tests
- executable README and guides for installation, catalog, Lua API, composition,
  policy, limits, operations, and upgrades
- architecture, compatibility, changelog, security, license/notices, and package metadata
- clean package-consumer test using only Hex-resolvable dependencies
- synchronized `0.1.0`, GitHub release, Hex package, HexDocs, and final CI verification

Out of scope:

- deferred engine syntax, languages, savepoints, network services, or distributed features
- weakening limits/security to broaden examples
- publication before every documented claim and package artifact is verified

## Release Contract

The package contains only required Elixir source/docs/metadata and no test data,
roadmaps, procedure source, credentials, local paths, build output, or cache.
A clean consumer installs it without the sibling repository. Every public
example executes in tests.

Release notes state exact compatible Tursox and Deflua versions and distinguish
language sandboxing from database authorization. Publication is monitored until
GitHub, Hex, HexDocs, and final CI agree on the release commit/version.

## Acceptance Criteria

- Full QA and clean-consumer tests pass from a clean checkout.
- Sandbox escape/resource/authorization suites pass with no leaked data.
- Composition, rollback, update, cache, timeout, and concurrent stress tests are stable.
- Docs contain no untested examples or unsupported security claims.
- Package contents and dependency licenses are audited.
- Version/changelog/docs/tag/package agree on `0.1.0`.
- GitHub release, Hex package, HexDocs, and final CI are verified.

## Test Strategy

Add malformed/random values/source, hostile Lua, deep composition, call storms,
large database values/results, source churn, process/pool shutdown, telemetry and
exception redaction, package unpack/consumer tests, and all documentation examples.
