# Compatibility

ROADMAP001 starts from these exact published dependencies:

| Component | Version | Purpose |
| --- | ---: | --- |
| Elixir | 1.20.x | package runtime and CI |
| OTP | 28.x | package runtime and CI |
| Tursox | 0.2.1 | checkout-bound transactions and ordered results |
| DBConnection | 2.10.2 | resolved through Tursox |
| `lua` | 1.0.2 | pure-Elixir Lua 5.3 VM |
| Telemetry | 1.4.2 | redacted operation events |
| Jason | 1.4.5 | JSON-compatible catalog metadata |
| ExDoc | 0.40.3 | documentation |

Verified public Tursox capabilities include `Tursox.Pool.transaction/3`,
checkout-bound `query/4` and `execute/4`, ordered `%Tursox.Result{}` rows and
columns, and transaction modes forwarded through DBConnection.

Verified Deflua capabilities include source parsing/chunks, fresh immutable VM
state, private state, host functions, and finite instruction, call-depth, and
string limits. Deflua's filesystem, process, environment, and module-loading
paths remain sandboxed.

ROADMAP001 intentionally does not depend on Turso runtime extensions, SQL
`CALL`, savepoint recovery, QuickJS, or private Tursox modules.

Baseline verified on 2026-08-05. Lockfile source and executable tests override
this prose if dependencies change.
