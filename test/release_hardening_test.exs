defmodule Tursox.Procedures.ReleaseHardeningTest do
  use ExUnit.Case, async: false

  alias Tursox.Procedures.{Error, Source.Database, Source.Memory}

  test "database catalog and application writes persist across pool/service reopen" do
    root = Path.join(System.tmp_dir!(), "tursox-procedures-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    path = Path.join(root, "procedures.db")
    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, pool} = Tursox.Pool.start_link(database: path, pool_size: 1)
    assert {:ok, _} = Database.install(pool)
    assert {:ok, _} = Tursox.Pool.execute(pool, "CREATE TABLE counters (value INTEGER NOT NULL)")
    assert {:ok, _} = Tursox.Pool.execute(pool, "INSERT INTO counters VALUES (0)")

    assert {:ok, published} =
             Database.publish(pool, "increment", """
             db.exec("UPDATE counters SET value = value + 1", {})
             return db.one("SELECT value FROM counters", {})
             """)

    {:ok, service} = Tursox.Procedures.start_link(pool: pool, source: {Database, []})

    assert {:ok, %{value: %{"value" => 1}, trace: [%{version: version}]}} =
             Tursox.Procedures.call(service, "increment")

    assert version == published.version
    :ok = Tursox.Procedures.stop(service)
    :ok = Tursox.Pool.stop(pool)

    {:ok, reopened} = Tursox.Pool.start_link(database: path, pool_size: 1)
    {:ok, service} = Tursox.Procedures.start_link(pool: reopened, source: {Database, []})
    assert {:ok, %{value: %{"value" => 2}}} = Tursox.Procedures.call(service, "increment")
    :ok = Tursox.Procedures.stop(service)
    :ok = Tursox.Pool.stop(reopened)
  end

  test "rejects invalid service and per-call configuration" do
    previous = Process.flag(:trap_exit, true)

    try do
      assert {:error, %Error{code: :invalid_argument}} =
               Tursox.Procedures.start_link(source: {Memory, self()})
    after
      Process.flag(:trap_exit, previous)
    end

    pool = start_supervised!({Tursox.Pool, id: make_ref(), database: :memory, pool_size: 1})
    source = start_supervised!({Memory, id: make_ref()})

    service =
      start_supervised!({Tursox.Procedures, id: make_ref(), pool: pool, source: {Memory, source}})

    assert {:error, %Error{code: :invalid_argument}} =
             Tursox.Procedures.call(service, "missing", %{}, policy: :not_allowed)
  end

  test "malformed source and values remain bounded and redacted" do
    pool = start_supervised!({Tursox.Pool, id: make_ref(), database: :memory, pool_size: 1})
    source = start_supervised!({Memory, id: make_ref()})

    service =
      start_supervised!({Tursox.Procedures, id: make_ref(), pool: pool, source: {Memory, source}})

    for {name, code} <- [
          {"syntax", "local = secret_source"},
          {"runtime", "return unknown.secret_value"},
          {"multi", "return 1, 2"}
        ] do
      assert {:ok, _} = Memory.publish(source, name, code)

      assert {:error, %Error{} = error} =
               Tursox.Procedures.call(service, name, %{"secret" => "hidden"})

      inspected = inspect(error)
      refute inspected =~ "secret_source"
      refute inspected =~ "secret_value"
      refute inspected =~ "hidden"
    end
  end

  test "high-cardinality user names do not create atoms" do
    source = start_supervised!({Memory, id: make_ref()})
    assert {:ok, _} = Memory.publish(source, "warm", "return true")
    assert {:ok, _} = Memory.list(source, nil)
    before_count = :erlang.system_info(:atom_count)

    for id <- 1..500 do
      assert {:ok, _} = Memory.publish(source, "tenant-#{id}-注文", "return #{id}")
    end

    after_count = :erlang.system_info(:atom_count)
    assert after_count - before_count < 10
    assert {:ok, procedures} = Memory.list(source, nil)
    assert length(procedures) == 501
  end
end
