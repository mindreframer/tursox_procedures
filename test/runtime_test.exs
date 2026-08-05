defmodule Tursox.Procedures.RuntimeTest do
  use ExUnit.Case, async: true

  alias Tursox.Procedures.{Cache, Error, Limits, Procedure, Runtime, Validation}

  setup do
    cache = start_supervised!({Cache, id: make_ref(), capacity: 2})
    {:ok, limits} = Limits.new(max_instructions: 2_000, max_string_bytes: 1_024)
    %{cache: cache, limits: limits}
  end

  test "passes arguments and normalizes scalar, map, and array results", context do
    assert {:ok, 42} = run(context, "return args.value", %{"value" => 42})

    assert {:ok, %{"ok" => true, "values" => [1, 2, 3]}} =
             run(context, "return {ok = true, values = {1, 2, 3}}", %{})
  end

  test "isolates globals between invocations", context do
    assert {:ok, 7} = run(context, "leaked = 7; return leaked", %{}, "first")
    assert {:ok, nil} = run(context, "return leaked", %{}, "second")
  end

  test "returns structured user failures without source", context do
    assert {:error, %Error{code: :runtime_error, operation: :fail} = error} =
             run(context, ~S[fail("invalid_order", "order cannot be approved")], %{})

    assert error.message == "order cannot be approved"
    assert error.metadata.failure_code == "invalid_order"
    refute inspect(error) =~ "fail("
  end

  test "reports compile and runtime failures without exposing source", context do
    assert {:error, %Error{code: :compile_error} = compile_error} =
             run(context, "local =", %{})

    assert {:error, %Error{code: :runtime_error} = runtime_error} =
             run(context, "return missing.value", %{})

    refute inspect(compile_error) =~ "local ="
    refute inspect(runtime_error) =~ "missing.value"
  end

  test "enforces instruction, call-depth, string, argument, and result limits", context do
    assert {:error, %Error{code: :resource_limit}} = run(context, "while true do end", %{})

    assert {:error, %Error{code: :resource_limit}} =
             run(context, "local function f() return f() end; return f()", %{})

    assert {:error, %Error{code: :resource_limit}} =
             run(context, ~S[return string.rep("x", 2048)], %{})

    tiny = %{context | limits: %{context.limits | max_argument_bytes: 10, max_result_bytes: 10}}

    assert {:error, %Error{code: :resource_limit}} =
             run(tiny, "return 1", %{"large" => String.duplicate("x", 20)})

    assert {:error, %Error{code: :resource_limit}} = run(tiny, ~S[return "0123456789abcdef"], %{})
  end

  test "keeps dangerous standard library paths sandboxed", context do
    for source <- [
          ~S[return os.getenv("HOME")],
          ~S[return require("anything")],
          ~S[return io.open("/tmp/nope")]
        ] do
      assert {:error, %Error{code: :runtime_error}} = run(context, source, %{}, source)
    end
  end

  test "uses immutable cache identity and evicts least recently used chunks", context do
    assert {:ok, 1} = run(context, "return 1", %{}, "one")
    assert {:ok, 1} = run(context, "return 1", %{}, "one")
    assert %{hits: 1, misses: 1, size: 1} = Cache.stats(context.cache)

    assert {:ok, 2} = run(context, "return 2", %{}, "two")
    assert {:ok, 3} = run(context, "return 3", %{}, "three")
    assert %{evictions: 1, size: 2} = Cache.stats(context.cache)
  end

  test "rejects a source/hash mismatch", context do
    procedure = procedure("bad", "return 1")
    procedure = %{procedure | source: "return 2"}

    assert {:error, %Error{code: :internal}} =
             Runtime.execute(context.cache, procedure, %{}, %{}, context.limits)
  end

  defp run(context, source, arguments, name \\ "procedure") do
    Runtime.execute(
      context.cache,
      procedure(name, source),
      arguments,
      %{opaque: true},
      context.limits
    )
  end

  defp procedure(name, source) do
    %Procedure{
      name: name,
      language: :lua,
      source: source,
      version: 1,
      source_hash: Validation.hash(source),
      enabled: true,
      metadata: %{}
    }
  end
end
