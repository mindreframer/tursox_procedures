# Architecture

Tursox Procedures is a standalone companion to Tursox. It resolves versioned
Lua source, compiles it with the pure-Elixir `lua` runtime, and executes it
through a deliberately small database capability surface.

```text
Application supervisor
    ├── Tursox.Pool
    ├── Procedure Source (database or memory)
    └── Tursox.Procedures service
          ├── bounded immutable chunk cache
          └── monitored worker per top-level call
                ├── one Tursox.Pool.transaction checkout
                ├── opaque execution context and aggregate budgets
                └── fresh Lua VM per procedure
                      ├── db.one / db.all / db.exec
                      ├── db.blob / db.null
                      ├── procedures.call
                      └── fail
```

The service GenServer owns configuration, cache, worker monitors, and timeout
handling; it does not execute user code. Calls therefore run concurrently. A
worker stores its opaque transaction context in process-local state, inaccessible
to Lua except through registered host APIs.

The top-level host owns the transaction. Nested procedures invoke the internal
runner with the same checkout and never recursively enter the public service.
Any nested failure makes the transaction uncommittable in 0.1.x.

Procedure source may be persisted, but execution remains application-level.
The package does not modify Turso's parser, add SQL `CALL`, or load a scripting
VM into Turso's native process boundary.
