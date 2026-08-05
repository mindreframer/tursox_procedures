defmodule Tursox.Procedures.DatabaseSourceTest do
  use ExUnit.Case, async: false

  alias Tursox.Procedures.Source.Database
  require Tursox.Procedures.TestSupport.SourceContract

  Tursox.Procedures.TestSupport.SourceContract.tests(fn context ->
    pool = context.database_source

    %{
      publish: &Database.publish(pool, &1, &2, &3),
      fetch: fn name -> in_transaction(pool, &Database.fetch([], &1, name)) end,
      list: fn -> in_transaction(pool, &Database.list([], &1)) end,
      disable: &Database.disable(pool, &1),
      enable: &Database.enable(pool, &1, &2)
    }
  end)

  setup do
    pool =
      start_supervised!(
        {Tursox.Pool, id: make_ref(), database: :memory, pool_size: 5, busy_timeout: 2_000}
      )

    assert {:ok, _result} = Database.install(pool)
    %{database_source: pool}
  end

  test "allocates unique versions under concurrent publication", %{database_source: pool} do
    versions =
      1..10
      |> Task.async_stream(
        fn value -> Database.publish(pool, "concurrent", "return #{value}") end,
        max_concurrency: 5,
        ordered: false,
        timeout: 10_000
      )
      |> Enum.map(fn {:ok, {:ok, procedure}} -> procedure.version end)

    assert Enum.sort(versions) == Enum.to_list(1..10)
  end

  test "rejects unsafe catalog identifiers", %{database_source: pool} do
    assert {:error, %Tursox.Procedures.Error{code: :invalid_argument}} =
             Database.install(pool, table: "procedures; DROP TABLE users")
  end

  test "detects a tampered source hash", %{database_source: pool} do
    assert {:ok, _} = Database.publish(pool, "tampered", "return 1")

    assert {:ok, _} =
             Tursox.Pool.execute(
               pool,
               "UPDATE tursox_procedures SET source_hash = 'bad' WHERE name = 'tampered'",
               []
             )

    assert {:error, %Tursox.Procedures.Error{code: :internal}} =
             in_transaction(pool, &Database.fetch([], &1, "tampered"))
  end

  defp in_transaction(pool, function) do
    case Tursox.Pool.transaction(pool, function) do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end
end
