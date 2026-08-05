defmodule Tursox.Procedures.TransactionalRuntimeTest do
  use ExUnit.Case, async: false

  alias Tursox.Procedures.{Cache, Error, Runner}
  alias Tursox.Procedures.Source.Memory

  defmodule DenyWrites do
    @behaviour Tursox.Procedures.Policy
    def authorize(:execute, _context), do: {:error, :writes_denied}
    def authorize(_operation, _context), do: :ok
  end

  setup do
    pool = start_supervised!({Tursox.Pool, id: make_ref(), database: :memory, pool_size: 1})
    source = start_supervised!({Memory, id: make_ref()})
    cache = start_supervised!({Cache, id: make_ref()})

    assert {:ok, _} =
             Tursox.Pool.execute(pool, "CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT)")

    %{pool: pool, source: source, cache: cache}
  end

  test "reads, compares, inserts, updates, and returns a value atomically", context do
    publish!(context, "upsert", """
    local row = db.one("SELECT value FROM items WHERE id = ?", {args.id})
    if row == nil then
      db.exec("INSERT INTO items(id, value) VALUES (?, ?)", {args.id, args.value})
    else
      db.exec("UPDATE items SET value = ? WHERE id = ?", {args.value, args.id})
    end
    return db.one("SELECT id, value FROM items WHERE id = ?", {args.id})
    """)

    assert {:ok, result} = call(context, "upsert", %{"id" => 1, "value" => "first"})
    assert result.value == %{"id" => 1, "value" => "first"}
    assert {:ok, result} = call(context, "upsert", %{"id" => 1, "value" => "second"})
    assert result.value == %{"id" => 1, "value" => "second"}
  end

  test "rolls back all prior writes after Lua and database failures", context do
    publish!(context, "lua_failure", """
    db.exec("INSERT INTO items(id, value) VALUES (?, ?)", {1, "before"})
    fail("stop", "stop now")
    """)

    assert {:error, %Error{code: :runtime_error}} = call(context, "lua_failure", %{})
    assert count(context.pool) == 0

    publish!(context, "database_failure", """
    db.exec("INSERT INTO items(id, value) VALUES (?, ?)", {1, "before"})
    db.exec("INSERT INTO items(id, value) VALUES (?, ?)", {1, "duplicate"})
    """)

    assert {:error, %Error{code: :database}} = call(context, "database_failure", %{})
    assert count(context.pool) == 0
  end

  test "policy denial executes no write and exposes a stable authorization error", context do
    publish!(
      context,
      "write",
      ~S[return db.exec("INSERT INTO items(value) VALUES (?)", {"secret"})]
    )

    assert {:error, %Error{code: :authorization} = error} =
             call(context, "write", %{}, policy: DenyWrites)

    assert error.metadata.reason_class == :writes_denied
    assert count(context.pool) == 0
    refute inspect(error) =~ "secret"
  end

  test "rejects transaction control from Lua, including after comments", context do
    publish!(context, "commit", ~S[return db.exec("COMMIT", {})])
    assert {:error, %Error{code: :authorization}} = call(context, "commit", %{})

    publish!(
      context,
      "comment_commit",
      "return db.exec(\"-- hidden\\n/* still hidden */ COMMIT\", {})"
    )

    assert {:error, %Error{code: :authorization}} = call(context, "comment_commit", %{})
  end

  test "round-trips explicit blobs, nulls, integers, reals, and text", context do
    assert {:ok, _} =
             Tursox.Pool.execute(
               context.pool,
               "CREATE TABLE values_test (b BLOB, n, i INTEGER, r REAL, t TEXT)"
             )

    publish!(context, "values", """
    db.exec("INSERT INTO values_test VALUES (?, ?, ?, ?, ?)", {
      db.blob(args.blob), db.null(), args.integer, args.real, args.text
    })
    return db.one("SELECT b, n, i, r, t FROM values_test", {})
    """)

    assert {:ok, result} =
             call(context, "values", %{
               "blob" => <<0, 255, 1>>,
               "integer" => 42,
               "real" => 1.5,
               "text" => "hello"
             })

    assert result.value == %{
             "b" => <<0, 255, 1>>,
             "n" => nil,
             "i" => 42,
             "r" => 1.5,
             "t" => "hello"
           }
  end

  test "bounds db.one, db.all, rows, statements, and database bytes", context do
    for id <- 1..5 do
      assert {:ok, _} =
               Tursox.Pool.execute(context.pool, "INSERT INTO items(id, value) VALUES (?, ?)", [
                 id,
                 "v#{id}"
               ])
    end

    publish!(context, "one_many", ~S[return db.one("SELECT id FROM items", {})])
    assert {:error, %Error{code: :database}} = call(context, "one_many", %{})

    publish!(context, "all", ~S[return db.all("SELECT id FROM items ORDER BY id", {})])
    assert {:error, %Error{code: :database}} = call(context, "all", %{}, limits: [max_rows: 2])

    publish!(
      context,
      "statements",
      "db.one(\"SELECT 1 AS n\", {}); db.one(\"SELECT 2 AS n\", {}); return true"
    )

    assert {:error, %Error{code: :resource_limit}} =
             call(context, "statements", %{}, limits: [max_statements: 1])

    publish!(context, "bytes", ~S[return db.all("SELECT value FROM items", {})])

    assert {:error, %Error{code: :resource_limit}} =
             call(context, "bytes", %{}, limits: [max_database_bytes: 10])
  end

  test "handles duplicate columns according to explicit policy", context do
    publish!(context, "duplicates", ~S[return db.one("SELECT 1 AS value, 2 AS value", {})])
    assert {:error, %Error{code: :database}} = call(context, "duplicates", %{})
    assert {:ok, result} = call(context, "duplicates", %{}, duplicate_columns: :last)
    assert result.value == %{"value" => 2}
  end

  defp call(context, name, arguments, options \\ []) do
    Runner.call(
      context.pool,
      {Memory, context.source},
      context.cache,
      name,
      arguments,
      options
    )
  end

  defp publish!(context, name, source) do
    assert {:ok, _procedure} = Memory.publish(context.source, name, source)
  end

  defp count(pool) do
    assert {:ok, %Tursox.Result{rows: [[count]]}} =
             Tursox.Pool.query(pool, "SELECT COUNT(*) FROM items")

    count
  end
end
