defmodule Tursox.Procedures.LuaAPI.Procedures do
  @moduledoc false

  use Lua.API, scope: "procedures"

  alias Tursox.Procedures.{Error, Execution, Runner, Runtime}

  deflua call(name, encoded_arguments), lua do
    handle = Lua.get_private!(lua, :procedure_context)

    result =
      with %Execution.Handle{} <- handle,
           true <- is_binary(name),
           {:ok, arguments} <- decode_arguments(lua, encoded_arguments),
           {:ok, value} <- Runner.run_one(handle, name, arguments) do
        {:ok, value}
      else
        {:error, %Error{} = error} -> Execution.fail(handle, error)
        _ -> Execution.fail(handle, invalid("nested procedure call received invalid arguments"))
      end

    case result do
      {:ok, value} -> Lua.encode_list!(lua, [encode_value(value, true)])
      {:error, _error} -> runtime_exception!("__tursox_host_error__")
    end
  end

  defp decode_arguments(lua, encoded) do
    lua
    |> Lua.decode!(encoded)
    |> Runtime.normalize_value()
    |> case do
      {:ok, arguments} when is_map(arguments) or is_list(arguments) -> {:ok, arguments}
      _ -> {:error, invalid("nested procedure arguments must be a table or array")}
    end
  rescue
    _ -> {:error, invalid("nested procedure arguments could not be decoded")}
  end

  defp encode_value(nil, true), do: nil
  defp encode_value(nil, false), do: {:userdata, :tursox_procedures_null}

  defp encode_value(value, _root) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, encode_value(item, false)} end)

  defp encode_value(value, _root) when is_list(value),
    do: Enum.map(value, &encode_value(&1, false))

  defp encode_value(value, _root), do: value

  defp invalid(message),
    do: %Error{code: :invalid_argument, operation: :nested_call, message: message}
end
