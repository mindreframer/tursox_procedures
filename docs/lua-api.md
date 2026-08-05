# Lua procedure API

Each procedure receives fresh Lua globals and an `args` value supplied by the
caller. A procedure returns zero or one value. Supported values are nil,
booleans, numbers, strings, arrays, and string-keyed tables.

## Database

```lua
local row = db.one("SELECT id, state FROM jobs WHERE id = ?", {args.id})
local rows = db.all("SELECT id FROM jobs WHERE state = ?", {"ready"})
local result = db.exec("UPDATE jobs SET state = ? WHERE id = ?", {"done", args.id})
```

`db.one` returns nil, one string-keyed row, or fails if the query produces more
than one row. `db.all` returns a bounded array. `db.exec` returns
`rows_affected` and `last_insert_rowid`.

Use explicit values where Lua cannot preserve SQL storage semantics:

```lua
db.exec("INSERT INTO values(blob_value, null_value) VALUES (?, ?)", {
  db.blob(args.bytes),
  db.null()
})
```

All SQL parameters are bound; data must not be interpolated into SQL strings.
Transaction-control statements are rejected because the host owns the complete
call-tree transaction.

## Composition

```lua
local result = procedures.call("reserve_inventory", {
  product_id = args.product_id,
  quantity = args.quantity
})
```

The child uses the same connection, transaction, caller policy, deadline, and
aggregate budgets, but receives a fresh Lua VM.

## Failure

```lua
if args.quantity <= 0 then
  fail("invalid_quantity", "quantity must be positive")
end
```

The failure code is safe metadata and the message is capped. Any unhandled or
caught child/host failure prevents commit.
