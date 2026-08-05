defmodule Tursox.Procedures.CapabilityTest do
  use ExUnit.Case, async: false

  test "Tursox transactions keep query work on one checked-out connection" do
    pool = start_supervised!({Tursox.Pool, database: :memory, pool_size: 1})

    assert {:ok, {:ok, %Tursox.Result{rows: [[42]]}}} =
             Tursox.Pool.transaction(pool, fn connection ->
               Tursox.Pool.query(connection, "SELECT ?", [42])
             end)
  end

  test "Deflua provides isolated state, private context, host functions, and limits" do
    lua =
      Lua.new(max_instructions: 1_000, max_call_depth: 16, max_string_bytes: 1_024)
      |> Lua.put_private(:context, %{id: 7})
      |> Lua.set!([:host_id], fn _args, state ->
        context = Lua.get_private!(state, :context)
        {[context.id], state}
      end)

    assert {[7], lua} = Lua.eval!(lua, "return host_id()")
    assert Lua.get_private!(lua, :context) == %{id: 7}

    assert_raise Lua.RuntimeException, ~r/instruction budget exceeded/, fn ->
      Lua.eval!(lua, "while true do end")
    end

    fresh = Lua.new(max_instructions: 1_000)
    assert {[nil], _fresh} = Lua.eval!(fresh, "return leaked_global")
  end
end
