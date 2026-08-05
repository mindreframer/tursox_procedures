defmodule Tursox.Procedures.LuaAPI.Database do
  @moduledoc false

  use Lua.API, scope: "db"

  alias Tursox.Procedures.{Error, Execution, Runtime}

  deflua one(sql, parameters), lua do
    database_call(lua, :query, sql, parameters, :one)
  end

  deflua all(sql, parameters), lua do
    database_call(lua, :query, sql, parameters, :all)
  end

  deflua exec(sql, parameters), lua do
    database_call(lua, :execute, sql, parameters, :exec)
  end

  deflua blob(value) when is_binary(value), lua do
    Lua.encode_list!(lua, [{:userdata, {:tursox_procedures_blob, value}}])
  end

  deflua blob(_value), _lua do
    runtime_exception!("db.blob expects a string")
  end

  deflua null(), lua do
    Lua.encode_list!(lua, [{:userdata, :tursox_procedures_null}])
  end

  defp database_call(lua, operation, sql, encoded_parameters, mode) do
    handle = Lua.get_private!(lua, :procedure_context)

    result =
      with %Execution.Handle{} <- handle,
           :ok <- Execution.ensure_active(handle),
           :ok <- validate_sql(sql, mode),
           {:ok, parameters} <- decode_parameters(lua, encoded_parameters),
           :ok <- Execution.check_deadline(handle),
           :ok <- Execution.charge(handle, :statements, 1),
           :ok <- Execution.authorize(handle, operation, %{sql: sql}),
           {:ok, value} <- execute(handle, sql, parameters, mode),
           :ok <- Execution.check_deadline(handle) do
        {:ok, value}
      else
        {:error, %Error{} = error} -> Execution.fail(handle, error)
        _ -> Execution.fail(handle, invalid("database API received invalid arguments"))
      end

    case result do
      {:ok, value} -> Lua.encode_list!(lua, [encode_database_value(value)])
      {:error, _error} -> runtime_exception!("__tursox_host_error__")
    end
  end

  defp execute(handle, sql, parameters, :one) do
    state = Execution.state(handle)

    case Tursox.Pool.query(state.connection, sql, parameters, max_rows: 2, chunk_size: 2) do
      {:ok, result} -> consume_query(handle, result, :one)
      {:error, error} -> database_error(handle, error)
    end
  end

  defp execute(handle, sql, parameters, :all) do
    state = Execution.state(handle)
    remaining = state.limits.max_rows - state.counters.rows

    if remaining <= 0 do
      Execution.fail(handle, limit("procedure rows limit exceeded"))
    else
      case Tursox.Pool.query(
             state.connection,
             sql,
             parameters,
             max_rows: remaining,
             chunk_size: min(remaining + 1, 500)
           ) do
        {:ok, result} -> consume_query(handle, result, :all)
        {:error, error} -> database_error(handle, error)
      end
    end
  end

  defp execute(handle, sql, parameters, :exec) do
    state = Execution.state(handle)

    case Tursox.Pool.execute(state.connection, sql, parameters) do
      {:ok, result} ->
        value = %{
          "rows_affected" => result.num_rows,
          "last_insert_rowid" => result.last_insert_rowid
        }

        with :ok <- Execution.charge(handle, :database_bytes, encoded_bytes(value)) do
          {:ok, value}
        end

      {:error, error} ->
        database_error(handle, error)
    end
  end

  defp consume_query(handle, result, mode) do
    rows = result.rows || []

    with :ok <- Execution.charge(handle, :rows, length(rows)),
         :ok <- Execution.charge(handle, :database_bytes, encoded_bytes(rows)),
         {:ok, maps} <- rows_to_maps(result, Execution.state(handle).duplicate_columns) do
      case {mode, maps} do
        {:one, []} ->
          {:ok, nil}

        {:one, [row]} ->
          {:ok, row}

        {:one, _rows} ->
          Execution.fail(handle, database_contract("db.one returned more than one row"))

        {:all, rows} ->
          {:ok, rows}
      end
    end
  end

  defp rows_to_maps(%Tursox.Result{columns: columns, rows: rows}, duplicate_policy) do
    names = Enum.map(columns || [], & &1.name)

    if duplicate_policy == :error and length(names) != MapSet.size(MapSet.new(names)) do
      {:error, database_contract("query returned duplicate column names")}
    else
      {:ok, Enum.map(rows || [], &row_to_map(names, &1, duplicate_policy))}
    end
  end

  defp row_to_map(names, row, :first), do: names |> Enum.zip(row) |> Enum.reverse() |> Map.new()
  defp row_to_map(names, row, _policy), do: Map.new(Enum.zip(names, row))

  defp decode_parameters(lua, encoded) do
    lua
    |> Lua.decode!(encoded)
    |> normalize_database_value(0)
    |> case do
      {:ok, parameters} when is_list(parameters) or is_map(parameters) -> {:ok, parameters}
      _ -> {:error, invalid("database parameters must be an array or table")}
    end
  rescue
    _ -> {:error, invalid("database parameters could not be decoded")}
  end

  defp validate_sql(sql, _mode) when not is_binary(sql),
    do: {:error, invalid("SQL must be a string")}

  defp validate_sql(sql, mode) do
    with {:ok, leading_statement} <- strip_leading_comments(sql) do
      cond do
        sql == "" or byte_size(sql) > 1_000_000 ->
          {:error, invalid("SQL is empty or too large")}

        Regex.match?(~r/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|END)\b/i, leading_statement) ->
          {:error,
           %Error{
             code: :authorization,
             operation: mode,
             message: "transaction control is owned by the procedure host"
           }}

        true ->
          :ok
      end
    end
  end

  defp strip_leading_comments(sql) do
    trimmed = String.trim_leading(sql)

    cond do
      String.starts_with?(trimmed, "--") ->
        case String.split(trimmed, "\n", parts: 2) do
          [_comment, rest] -> strip_leading_comments(rest)
          [_comment] -> {:ok, ""}
        end

      String.starts_with?(trimmed, "/*") ->
        case String.split(trimmed, "*/", parts: 2) do
          [_comment, rest] -> strip_leading_comments(rest)
          [_unterminated] -> {:error, invalid("SQL has an unterminated leading comment")}
        end

      true ->
        {:ok, trimmed}
    end
  end

  defp normalize_database_value({:userdata, {:tursox_procedures_blob, value}}, _depth)
       when is_binary(value),
       do: {:ok, {:blob, value}}

  defp normalize_database_value({:userdata, :tursox_procedures_null}, _depth), do: {:ok, nil}
  defp normalize_database_value([], _depth), do: {:ok, []}

  defp normalize_database_value(_value, depth) when depth > 64,
    do: {:error, invalid("database parameters are too deeply nested")}

  defp normalize_database_value(value, depth) when is_list(value) do
    if Enum.all?(value, &match?({_, _}, &1)) do
      keys = Enum.map(value, &elem(&1, 0))

      if Enum.all?(keys, &(is_integer(&1) and &1 > 0)) do
        values = Map.new(value)
        normalize_database_list(Enum.map(1..Enum.max(keys), &Map.get(values, &1)), depth + 1)
      else
        Enum.reduce_while(value, {:ok, %{}}, fn
          {key, item}, {:ok, result} when is_binary(key) ->
            case normalize_database_value(item, depth + 1) do
              {:ok, normalized} -> {:cont, {:ok, Map.put(result, key, normalized)}}
              error -> {:halt, error}
            end

          _pair, _result ->
            {:halt, {:error, invalid("named database parameter keys must be strings")}}
        end)
      end
    else
      normalize_database_list(value, depth + 1)
    end
  end

  defp normalize_database_value(value, _depth), do: Runtime.normalize_value(value)

  defp normalize_database_list(values, depth) do
    Enum.reduce_while(values, {:ok, []}, fn item, {:ok, result} ->
      case normalize_database_value(item, depth) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | result]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, result} -> {:ok, Enum.reverse(result)}
      error -> error
    end
  end

  defp database_error(handle, error) do
    procedure = Execution.current_procedure(handle)

    wrapped = %Error{
      code: :database,
      operation: :database,
      message: "database operation failed",
      procedure: procedure && procedure.name,
      version: procedure && procedure.version,
      metadata: %{class: error_class(error)}
    }

    Execution.fail(handle, wrapped)
  end

  defp error_class(%{code: code}) when is_atom(code), do: code
  defp error_class(%{__struct__: module}), do: module
  defp error_class(_error), do: :other

  defp encode_database_value(value), do: encode_database_value(value, true)

  defp encode_database_value(nil, true), do: nil
  defp encode_database_value(nil, false), do: {:userdata, :tursox_procedures_null}

  defp encode_database_value({:blob, value}, _root) when is_binary(value),
    do: {:userdata, {:tursox_procedures_blob, value}}

  defp encode_database_value(value, _root) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, encode_database_value(item, false)} end)

  defp encode_database_value(value, _root) when is_list(value),
    do: Enum.map(value, &encode_database_value(&1, false))

  defp encode_database_value(value, _root), do: value

  defp encoded_bytes(value), do: byte_size(:erlang.term_to_binary(value))

  defp invalid(message),
    do: %Error{code: :invalid_argument, operation: :database, message: message}

  defp limit(message), do: %Error{code: :resource_limit, operation: :rows, message: message}

  defp database_contract(message),
    do: %Error{code: :database, operation: :query, message: message}
end
