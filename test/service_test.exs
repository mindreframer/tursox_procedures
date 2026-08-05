defmodule Tursox.Procedures.ServiceTest do
  use ExUnit.Case, async: false

  alias Tursox.Procedures.{Error, Source.Memory}

  setup do
    pool =
      start_supervised!(
        {Tursox.Pool, id: make_ref(), database: :memory, pool_size: 4, busy_timeout: 5_000}
      )

    source = start_supervised!({Memory, id: make_ref()})

    assert {:ok, _} =
             Tursox.Pool.execute(pool, "CREATE TABLE calls (id INTEGER PRIMARY KEY, value TEXT)")

    %{pool: pool, source: source}
  end

  test "runs concurrent isolated calls through a caller-supervised service", context do
    publish!(context, "insert", ~S[
      db.exec("INSERT INTO calls(id, value) VALUES (?, ?)", {args.id, args.value})
      local temp = args.value
      return {id = args.id, value = temp}
    ])

    service = service!(context)

    results =
      1..20
      |> Task.async_stream(
        fn id ->
          Tursox.Procedures.call(service, "insert", %{"id" => id, "value" => "v#{id}"})
        end,
        max_concurrency: 8,
        timeout: 10_000
      )
      |> Enum.map(fn {:ok, {:ok, result}} -> result.value["id"] end)

    assert Enum.sort(results) == Enum.to_list(1..20)

    assert {:ok, %Tursox.Result{rows: [[20]]}} =
             Tursox.Pool.query(context.pool, "SELECT COUNT(*) FROM calls")

    assert %{active_calls: 0, cache: %{size: 1, misses: 1, hits: 19}} =
             Tursox.Procedures.metadata(service)
  end

  test "source updates select new immutable versions and refresh only affects cache", context do
    assert {:ok, first} = Memory.publish(context.source, "versioned", "return 1")
    service = service!(context)
    assert {:ok, result} = Tursox.Procedures.call(service, "versioned")
    assert result.value == 1
    assert hd(result.trace).version == first.version

    assert {:ok, second} = Memory.publish(context.source, "versioned", "return 2")
    assert {:ok, result} = Tursox.Procedures.call(service, "versioned")
    assert result.value == 2
    assert hd(result.trace).version == second.version
    assert :ok = Tursox.Procedures.refresh(service)
    assert %{cache: %{size: 0}} = Tursox.Procedures.metadata(service)
  end

  @tag capture_log: true
  test "host timeout kills a call, rolls back, and leaves service usable", context do
    publish!(context, "timeout", ~S[
      db.exec("INSERT INTO calls(id, value) VALUES (1, 'before')", {})
      while true do end
    ])
    publish!(context, "healthy", "return 42")

    service =
      service!(context,
        limits: [timeout: 20, max_instructions: 1_000_000_000, max_heap_size: 32 * 1024 * 1024]
      )

    assert {:error, %Error{code: :timeout}} = Tursox.Procedures.call(service, "timeout")
    Process.sleep(20)

    assert {:ok, %Tursox.Result{rows: [[0]]}} =
             Tursox.Pool.query(context.pool, "SELECT COUNT(*) FROM calls")

    assert {:ok, %{value: 42}} = Tursox.Procedures.call(service, "healthy")
  end

  @tag capture_log: true
  test "heap policy terminates allocation bombs without stopping the service", context do
    publish!(context, "heap", """
    local values = {}
    for i = 1, 1000000 do
      values[i] = {value = i, text = "allocation"}
    end
    return #values
    """)

    publish!(context, "healthy_after_heap", "return 7")

    service =
      service!(context,
        limits: [
          timeout: 5_000,
          max_heap_size: 1_000_000,
          max_instructions: 1_000_000_000
        ]
      )

    assert {:error, %Error{code: :resource_limit}} = Tursox.Procedures.call(service, "heap")
    assert {:ok, %{value: 7}} = Tursox.Procedures.call(service, "healthy_after_heap")
  end

  @tag capture_log: true
  test "emits redacted call telemetry", context do
    publish!(context, "telemetry", "return args.value")
    service = service!(context)
    test_pid = self()
    handler = "service-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:tursox_procedures, :call, :start],
          [:tursox_procedures, :call, :stop],
          [:tursox_procedures, :procedure, :stop],
          [:tursox_procedures, :cache, :stop]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)
    assert {:ok, _} = Tursox.Procedures.call(service, "telemetry", %{"value" => "top-secret"})
    assert_receive {:telemetry, [:tursox_procedures, :call, :start], _, start_metadata}
    assert_receive {:telemetry, [:tursox_procedures, :cache, :stop], _, cache_metadata}
    assert_receive {:telemetry, [:tursox_procedures, :procedure, :stop], _, procedure_metadata}
    assert_receive {:telemetry, [:tursox_procedures, :call, :stop], _, stop_metadata}
    refute inspect(start_metadata) =~ "top-secret"
    refute inspect(cache_metadata) =~ "top-secret"
    refute inspect(procedure_metadata) =~ "top-secret"
    refute inspect(stop_metadata) =~ "top-secret"
    assert stop_metadata.outcome == :ok
  end

  test "multiple services with overlapping names remain isolated", context do
    second_source = start_supervised!({Memory, id: make_ref()})
    assert {:ok, _} = Memory.publish(context.source, "same", "return 1")
    assert {:ok, _} = Memory.publish(second_source, "same", "return 2")
    first = service!(context, id: make_ref())
    second = service!(%{context | source: second_source}, id: make_ref())
    assert {:ok, %{value: 1}} = Tursox.Procedures.call(first, "same")
    assert {:ok, %{value: 2}} = Tursox.Procedures.call(second, "same")
  end

  defp service!(context, options \\ []) do
    start_supervised!(
      {Tursox.Procedures,
       Keyword.merge(
         [
           id: Keyword.get(options, :id, make_ref()),
           pool: context.pool,
           source: {Memory, context.source}
         ],
         Keyword.delete(options, :id)
       )}
    )
  end

  defp publish!(context, name, source), do: Memory.publish(context.source, name, source)
end
