# AGENTS.md

## Roadmaps

- Work is roadmap-driven. Treat a roadmap as an execution contract.
- Layout: one `@meta/@pm/ROADMAP00X.md`; usually seven epics; usually seven phases per epic.
- Each epic has a spec and a plan in `@meta/@pm/roadmap00x/`. The plan contains the phase checkboxes.
- Read the overview, references, and every epic file before coding.
- Execute epics and phases in dependency order.
- Implement the matching unit/integration tests for every phase and epic.
- Check a phase only when its code, tests, and acceptance criteria pass. Never check work optimistically.
- After every epic, run `bin/qa_check.sh`. Fix all failures.
- Commit each green epic as `roadmap00x - epic x - <outcome>` with a concise body stating result and verification.
- Given a roadmap, finish it end to end. Do not stop between phases. Do not ask routine questions. Inspect, make the smallest reasonable assumption, and continue.

## Code

- Use the least abstraction that solves the current problem.
- Prefer direct, readable, maintainable code. Avoid speculative frameworks.
- Minimize dependencies. Each dependency adds build, security, upgrade, and release cost.
- Keep Tursox and Lua integration behind their public, version-matched APIs.
- Never add a sibling path dependency to committed package metadata.
- User procedure source is untrusted. Preserve sandbox, authorization, transaction, redaction, and resource-limit boundaries in every change.
- Keep roadmap commits focused. No unrelated cleanup.

## Release

- A finished roadmap normally bumps the version. Synchronize Mix metadata, lockfiles, changelog, README, docs, and examples.
- Run full QA, docs, package inspection, and clean-consumer tests before release.
- Publish only dependencies available from Hex; replace development path/git references before package verification.
- Monitor GitHub CI, GitHub release, Hex package, and HexDocs publication until all are verified.
- Report success only after code, tests, docs, commits, package contents, publication, and CI are green.
