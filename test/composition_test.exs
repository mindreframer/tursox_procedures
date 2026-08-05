defmodule Tursox.Procedures.CompositionTest do
  use ExUnit.Case, async: false

  alias Tursox.Procedures.{Cache, Error, Runner}
  alias Tursox.Procedures.Source.Memory

  defmodule DenySecretChild do
    @behaviour Tursox.Procedures.Policy

    def authorize(:call, %{callee: %{name: "secret_child"}}), do: {:error, :child_denied}
    def authorize(_operation, _context), do: :ok
  end

  setup do
    pool = start_supervised!({Tursox.Pool, id: make_ref(), database: :memory, pool_size: 1})
    source = start_supervised!({Memory, id: make_ref()})
    cache = start_supervised!({Cache, id: make_ref()})
    assert {:ok, _} = Tursox.Pool.execute(pool, "CREATE TABLE events (name TEXT NOT NULL)")
    %{pool: pool, source: source, cache: cache}
  end

  test "A to B to C shares one transaction and records immutable call order", context do
    publish!(
      context,
      "c",
      ~S[db.exec("INSERT INTO events VALUES (?)", {"c"}); return {level = "c"}]
    )

    publish!(context, "b", """
    db.exec("INSERT INTO events VALUES (?)", {"b"})
    local child = procedures.call("c", {})
    return {level = "b", child = child}
    """)

    publish!(context, "a", """
    db.exec("INSERT INTO events VALUES (?)", {"a"})
    return procedures.call("b", {})
    """)

    assert {:ok, result} = call(context, "a")
    assert result.value == %{"level" => "b", "child" => %{"level" => "c"}}
    assert Enum.map(result.trace, & &1.name) == ["a", "b", "c"]
    assert rows(context.pool) == [["a"], ["b"], ["c"]]
  end

  test "a child failure rolls back ancestors even when Lua catches it", context do
    publish!(
      context,
      "child",
      ~S[db.exec("INSERT INTO events VALUES (?)", {"child"}); fail("no", "child failed")]
    )

    publish!(context, "parent", """
    db.exec("INSERT INTO events VALUES (?)", {"parent"})
    local ok, error = pcall(function() procedures.call("child", {}) end)
    return {caught = not ok}
    """)

    assert {:error, %Error{code: :runtime_error, procedure: "child"}} = call(context, "parent")
    assert rows(context.pool) == []
  end

  test "rejects direct and indirect cycles", context do
    publish!(context, "direct", ~S[return procedures.call("direct", {})])
    assert {:error, %Error{code: :call_cycle}} = call(context, "direct")

    publish!(context, "left", ~S[return procedures.call("right", {})])
    publish!(context, "right", ~S[return procedures.call("left", {})])
    assert {:error, %Error{code: :call_cycle}} = call(context, "left")
  end

  test "enforces procedure depth and total call count across fresh VMs", context do
    publish!(context, "three", "return true")
    publish!(context, "two", ~S[return procedures.call("three", {})])
    publish!(context, "one", ~S[return procedures.call("two", {})])

    assert {:error, %Error{code: :call_depth}} =
             call(context, "one", limits: [max_procedure_depth: 2])

    assert {:error, %Error{code: :resource_limit}} =
             call(context, "one", limits: [max_procedure_calls: 2])
  end

  test "propagates caller policy to every child without privilege escalation", context do
    publish!(
      context,
      "secret_child",
      ~S[db.exec("INSERT INTO events VALUES (?)", {"secret"}); return true]
    )

    publish!(context, "parent", ~S[return procedures.call("secret_child", {})])

    assert {:error, %Error{code: :authorization}} =
             call(context, "parent", policy: DenySecretChild, caller: %{role: :user})

    assert rows(context.pool) == []
  end

  test "aggregates result-byte budgets across children", context do
    publish!(context, "child", ~S[return "1234567890"])

    publish!(context, "parent", """
    local a = procedures.call("child", {})
    local b = procedures.call("child", {})
    return a .. b
    """)

    assert {:error, %Error{code: :resource_limit}} =
             call(context, "parent", limits: [max_result_bytes: 40])
  end

  defp call(context, name, options \\ []) do
    Runner.call(context.pool, {Memory, context.source}, context.cache, name, %{}, options)
  end

  defp publish!(context, name, source) do
    assert {:ok, _} = Memory.publish(context.source, name, source)
  end

  defp rows(pool) do
    assert {:ok, %Tursox.Result{rows: rows}} =
             Tursox.Pool.query(pool, "SELECT name FROM events ORDER BY rowid")

    rows
  end
end
