defmodule Tursox.Procedures.Runtime do
  @moduledoc "Isolated, finite Deflua execution for one immutable procedure."

  alias Tursox.Procedures.{Cache, Error, Execution, Limits, Procedure}
  alias Tursox.Procedures.LuaAPI.{Core, Database, Procedures}

  @failure_prefix "__tursox_fail__"

  @spec execute(pid(), Procedure.t(), term(), term(), Limits.t()) ::
          {:ok, term()} | {:error, Error.t()}
  def execute(cache, %Procedure{} = procedure, arguments, private_context, %Limits{} = limits) do
    with :ok <- encoded_size(arguments, limits.max_argument_bytes, :arguments),
         {:ok, chunk} <- Cache.fetch(cache, procedure) do
      lua =
        Lua.new(
          max_instructions: limits.max_instructions,
          max_call_depth: limits.max_lua_call_depth,
          max_string_bytes: limits.max_string_bytes
        )
        |> Lua.put_private(:procedure_context, private_context)
        |> Lua.load_api(Core)
        |> Lua.load_api(Database)
        |> Lua.load_api(Procedures)
        |> Lua.set!([:args], arguments)

      run(lua, chunk, procedure, limits, private_context)
    end
  rescue
    exception in Lua.RuntimeException ->
      runtime_error(exception, procedure, private_context)

    exception in Lua.CompilerException ->
      compile_error(exception, procedure)

    exception ->
      {:error,
       %Error{
         code: :internal,
         operation: :execute,
         message: "procedure runtime failed internally",
         procedure: procedure.name,
         version: procedure.version,
         metadata: %{class: exception.__struct__}
       }}
  catch
    kind, _reason ->
      {:error,
       %Error{
         code: :internal,
         operation: :execute,
         message: "procedure runtime terminated",
         procedure: procedure.name,
         version: procedure.version,
         metadata: %{kind: kind}
       }}
  end

  defp run(lua, chunk, procedure, limits, private_context) do
    case Lua.eval!(lua, chunk) do
      {[], _lua} -> {:ok, nil}
      {[value], _lua} -> normalize_and_bound(value, limits.max_result_bytes, procedure)
      {_values, _lua} -> invalid_result(procedure, "procedure must return zero or one value")
    end
  rescue
    exception in Lua.RuntimeException -> runtime_error(exception, procedure, private_context)
    exception in Lua.CompilerException -> compile_error(exception, procedure)
  end

  @doc false
  def normalize_value(value), do: normalize(value, 0)

  defp normalize_and_bound(value, max_bytes, procedure) do
    with {:ok, normalized} <- normalize_value(value),
         :ok <- encoded_size(normalized, max_bytes, :result) do
      {:ok, normalized}
    else
      {:error, %Error{} = error} ->
        {:error, %{error | procedure: procedure.name, version: procedure.version}}
    end
  end

  defp normalize({:userdata, {:tursox_procedures_blob, value}}, _depth) when is_binary(value),
    do: {:ok, value}

  defp normalize({:userdata, :tursox_procedures_null}, _depth), do: {:ok, nil}

  defp normalize(value, _depth)
       when is_nil(value) or is_boolean(value) or is_number(value) or is_binary(value),
       do: {:ok, value}

  defp normalize(_value, depth) when depth > 64,
    do: {:error, conversion_error("returned value is too deeply nested")}

  defp normalize(value, depth) when is_list(value) do
    cond do
      Enum.all?(value, &match?({_, _}, &1)) -> normalize_table(value, depth + 1)
      true -> normalize_list(value, depth + 1)
    end
  end

  defp normalize(_value, _depth),
    do: {:error, conversion_error("procedure returned an unsupported value")}

  defp normalize_table([], _depth), do: {:ok, %{}}

  defp normalize_table(pairs, depth) do
    keys = Enum.map(pairs, &elem(&1, 0))

    if keys == Enum.to_list(1..length(keys)) do
      pairs |> Enum.map(&elem(&1, 1)) |> normalize_list(depth)
    else
      Enum.reduce_while(pairs, {:ok, %{}}, fn
        {key, value}, {:ok, result} when is_binary(key) ->
          case normalize(value, depth) do
            {:ok, normalized} -> {:cont, {:ok, Map.put(result, key, normalized)}}
            error -> {:halt, error}
          end

        _pair, _result ->
          {:halt,
           {:error, conversion_error("returned table keys must be strings or a contiguous array")}}
      end)
    end
  end

  defp normalize_list(values, depth) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, result} ->
      case normalize(value, depth) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | result]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, result} -> {:ok, Enum.reverse(result)}
      error -> error
    end
  end

  defp encoded_size(value, max_bytes, operation) do
    if byte_size(:erlang.term_to_binary(value)) <= max_bytes do
      :ok
    else
      {:error,
       %Error{
         code: :resource_limit,
         operation: operation,
         message: "#{operation} exceed the configured byte limit"
       }}
    end
  rescue
    _ -> {:error, conversion_error("value cannot be encoded")}
  end

  defp runtime_error(exception, procedure, private_context) do
    raw = Exception.message(exception)

    if String.contains?(raw, "__tursox_host_error__") and
         match?(%Execution.Handle{}, private_context) and Execution.error(private_context) do
      {:error, Execution.error(private_context)}
    else
      user_or_generic_runtime_error(raw, exception, procedure)
    end
  end

  defp user_or_generic_runtime_error(raw, exception, procedure) do
    case String.split(raw, @failure_prefix, parts: 2) do
      [_before, payload] ->
        case String.split(payload, <<0>>, parts: 2) do
          [code, message] ->
            {:error,
             %Error{
               code: :runtime_error,
               operation: :fail,
               message: String.slice(message, 0, 512),
               procedure: procedure.name,
               version: procedure.version,
               line: exception_line(exception),
               metadata: %{failure_code: String.slice(code, 0, 64)}
             }}

          _ ->
            generic_runtime_error(exception, procedure)
        end

      _ ->
        generic_runtime_error(exception, procedure)
    end
  end

  defp generic_runtime_error(exception, procedure) do
    message = Exception.message(exception)

    code =
      if String.contains?(message, ["instruction budget exceeded", "stack overflow", "too large"]),
         do: :resource_limit,
         else: :runtime_error

    {:error,
     %Error{
       code: code,
       operation: :execute,
       message:
         if(code == :resource_limit,
           do: "Lua resource limit exceeded",
           else: "Lua runtime failed"
         ),
       procedure: procedure.name,
       version: procedure.version,
       line: exception_line(exception)
     }}
  end

  defp compile_error(exception, procedure) do
    {:error,
     %Error{
       code: :compile_error,
       operation: :compile,
       message: "Lua source did not compile",
       procedure: procedure.name,
       version: procedure.version,
       line: exception_line(exception)
     }}
  end

  defp invalid_result(procedure, message) do
    {:error,
     %Error{
       code: :runtime_error,
       operation: :result,
       message: message,
       procedure: procedure.name,
       version: procedure.version
     }}
  end

  defp conversion_error(message),
    do: %Error{code: :runtime_error, operation: :result, message: message}

  defp exception_line(exception) do
    case Map.get(exception, :line) do
      line when is_integer(line) and line > 0 -> line
      _ -> nil
    end
  end
end
