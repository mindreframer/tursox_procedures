# Architecture

Tursox Procedures is a standalone companion to Tursox. It stores or resolves
user-defined Lua source, compiles it with the pure-Elixir `lua` runtime, and
executes it through a deliberately small database capability surface.

```text
Application
    └── Tursox.Procedures.call/4
          ├── Source (database or memory)
          ├── compiled chunk cache
          ├── isolated Lua VM
          │     ├── db.one / db.all / db.exec
          │     ├── procedures.call
          │     └── fail
          └── Tursox.Pool.transaction/3
                └── one checked-out connection for the complete call tree
```

The top-level host call owns the transaction. Nested procedures share the same
checked-out connection and never begin, commit, or roll back independently.
Any nested failure makes the outer transaction uncommittable in the initial
contract.

Procedure source may be persisted, but execution remains an application-level
concern. This package will not modify Turso's parser, add SQL `CALL` syntax, or
load a scripting VM into Turso's native process boundary.

See `@meta/@pm/ROADMAP001.md` for the planned contracts and acceptance gates.
