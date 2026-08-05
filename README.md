# Tursox Procedures

[![CI](https://github.com/mindreframer/tursox_procedures/actions/workflows/ci.yml/badge.svg)](https://github.com/mindreframer/tursox_procedures/actions/workflows/ci.yml)

`Tursox Procedures` is a standalone companion to
[Tursox](https://github.com/mindreframer/tursox). It executes user-defined,
versioned Lua 5.3 procedures through a small database capability API while one
checked-out Tursox connection and transaction cover the complete procedure call
tree.

The Lua VM is the pure-Elixir [`lua`](https://deflua.com/) implementation. No
Lua NIF, Turso runtime extension, filesystem API, or network API is loaded.

## Installation

```elixir
def deps do
  [
    {:tursox_procedures, "~> 0.1.0"}
  ]
end
```

Tursox Procedures 0.1.x requires Tursox 0.2.1 and `lua` 1.0.2.

## Quick start

Start a Tursox pool, a source, and a procedure service under your supervisor:

```elixir
children = [
  {Tursox.Pool,
   name: MyDatabase,
   database: "application.db",
   pool_size: 4,
   busy_timeout: 5_000},
  {Tursox.Procedures.Source.Memory, name: MyProcedureSource},
  {Tursox.Procedures,
   name: MyProcedures,
   pool: MyDatabase,
   source: {Tursox.Procedures.Source.Memory, MyProcedureSource}}
]
```

Publish user source:

```elixir
{:ok, procedure} =
  Tursox.Procedures.Source.Memory.publish(
    MyProcedureSource,
    "approve_order",
    """
    local order = db.one(
      "SELECT status FROM orders WHERE id = ?",
      {args.order_id}
    )

    if order == nil then
      fail("not_found", "order does not exist")
    end

    procedures.call("reserve_inventory", {
      order_id = args.order_id
    })

    db.exec(
      "UPDATE orders SET status = ? WHERE id = ?",
      {"approved", args.order_id}
    )

    return {order_id = args.order_id, status = "approved"}
    """
  )
```

Call it by name:

```elixir
{:ok, result} =
  Tursox.Procedures.call(
    MyProcedures,
    "approve_order",
    %{"order_id" => 42},
    caller: %{user_id: "alice"}
  )

result.value
#=> %{"order_id" => 42, "status" => "approved"}
```

## Database-backed catalog

Catalog creation is explicit; starting a service never changes application
schema:

```elixir
alias Tursox.Procedures.Source.Database

{:ok, _} = Database.install(MyDatabase)
{:ok, procedure} = Database.publish(MyDatabase, "approve_order", lua_source)

children = [
  {Tursox.Procedures,
   name: MyProcedures,
   pool: MyDatabase,
   source: {Database, []}}
]
```

Every publication creates a new immutable `{name, version, source_hash}`.
Compiled chunks use that identity, so an update cannot replace code underneath a
running call.

## Transaction and composition semantics

The top-level host owns commit and rollback. Nested procedures:

- reuse the exact parent checkout and transaction;
- execute in fresh Lua VMs;
- inherit caller policy and aggregate limits;
- record exact version/hash trace entries;
- never begin or commit independently.

Any child failure makes the complete transaction uncommittable, even when Lua
catches the child error with `pcall`. Recoverable child savepoints are not part
of 0.1.x.

## Security model

Deflua blocks filesystem, process, environment, module-loading, and dangerous OS
paths by default. Tursox Procedures additionally applies finite instruction,
Lua depth, string, source, argument, result, statement, row, database-byte,
procedure-call, host timeout, and BEAM heap limits.

A language sandbox is **not database authorization**. The default
`Policy.AllowAll` is only for trusted procedure authors. Applications accepting
untrusted procedure authors should provide a policy module that approves each
`:call`, `:query`, and `:execute` operation. Raw SQL has the authority of the
configured Tursox connection.

See the guides for the catalog, Lua API, composition, security/limits,
operations, architecture, and exact compatibility contract.

## Development

```sh
mix deps.get
bin/qa_check.sh
```

## License

MIT. Dependency notices are in `THIRD_PARTY_NOTICES.md`.
