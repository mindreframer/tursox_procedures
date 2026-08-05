# Tursox Procedures

`Tursox Procedures` is a planned companion package for
[Tursox](https://github.com/mindreframer/tursox). It will execute user-defined,
database-backed Lua procedures through a small capability API while keeping one
Tursox connection and transaction for the complete procedure call tree.

The package is intentionally separate from Tursox. Tursox remains the focused
database driver; this package will own procedure storage, compilation, sandbox
policy, composition, resource limits, and observability.

## Status

The repository is scaffolded and ROADMAP001 is planned. No procedure execution
API is implemented yet and `0.1.0` has not been released.

The intended public shape is:

```elixir
Tursox.Procedures.call(MyProcedures, "approve_order", %{
  order_id: 42,
  approved_by: "alice"
})
```

A procedure will be able to use bounded host capabilities such as:

```lua
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
```

The outer host call owns commit and rollback. Nested procedures will share the
same checked-out Tursox connection and transaction.

## Development

```sh
mix deps.get
bin/qa_check.sh
```

Project execution is governed by `AGENTS.md` and
`@meta/@pm/ROADMAP001.md` in the source repository.

## License

MIT. See the repository `LICENSE` file.
