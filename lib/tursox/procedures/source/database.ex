defmodule Tursox.Procedures.Source.Database do
  @moduledoc "Explicit Tursox-backed procedure catalog and source adapter."

  @behaviour Tursox.Procedures.Source

  alias Tursox.Procedures.{Error, Procedure, Validation}

  @default_table "tursox_procedures"
  @columns "name, language, source, version, source_hash, enabled, metadata"

  def install(pool, options \\ []) do
    with {:ok, table} <- table(options) do
      sql = """
      CREATE TABLE IF NOT EXISTS #{table} (
        name TEXT NOT NULL,
        language TEXT NOT NULL,
        source TEXT NOT NULL,
        version INTEGER NOT NULL CHECK (version > 0),
        source_hash TEXT NOT NULL,
        enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
        metadata TEXT NOT NULL,
        PRIMARY KEY (name, version)
      )
      """

      execute(pool, sql, [])
    end
  end

  def publish(pool, name, source, metadata \\ %{}, options \\ []) do
    with {:ok, table} <- table(options),
         {:ok, procedure} <-
           Validation.procedure(
             name,
             source,
             metadata,
             Keyword.get(options, :max_source_bytes, 256_000)
           ),
         {:ok, metadata_json} <- encode_metadata(metadata) do
      transaction(pool, fn connection ->
        with {:ok, %Tursox.Result{rows: [[max_version]]}} <-
               Tursox.Pool.query(
                 connection,
                 "SELECT COALESCE(MAX(version), 0) FROM #{table} WHERE name = ?",
                 [name]
               ),
             version = max_version + 1,
             {:ok, _result} <-
               Tursox.Pool.execute(connection, "UPDATE #{table} SET enabled = 0 WHERE name = ?", [
                 name
               ]),
             {:ok, _result} <-
               Tursox.Pool.execute(
                 connection,
                 "INSERT INTO #{table} (#{@columns}) VALUES (?, 'lua', ?, ?, ?, 1, ?)",
                 [name, source, version, procedure.source_hash, metadata_json]
               ) do
          {:ok, %{procedure | version: version}}
        end
      end)
    end
  end

  def disable(pool, name, options \\ []) do
    with :ok <- Validation.name(name),
         {:ok, table} <- table(options),
         {:ok, result} <- execute(pool, "UPDATE #{table} SET enabled = 0 WHERE name = ?", [name]) do
      if result.num_rows > 0, do: :ok, else: not_found(name)
    end
  end

  def enable(pool, name, version, options \\ [])

  def enable(pool, name, version, options) when is_integer(version) and version > 0 do
    with :ok <- Validation.name(name),
         {:ok, table} <- table(options) do
      transaction(pool, fn connection ->
        with {:ok, %Tursox.Result{rows: [[count]]}} <-
               Tursox.Pool.query(
                 connection,
                 "SELECT COUNT(*) FROM #{table} WHERE name = ? AND version = ?",
                 [name, version]
               ),
             true <- count == 1 || not_found(name),
             {:ok, _} <-
               Tursox.Pool.execute(connection, "UPDATE #{table} SET enabled = 0 WHERE name = ?", [
                 name
               ]),
             {:ok, _} <-
               Tursox.Pool.execute(
                 connection,
                 "UPDATE #{table} SET enabled = 1 WHERE name = ? AND version = ?",
                 [name, version]
               ) do
          :ok
        end
      end)
    end
  end

  def enable(_pool, name, _version, _options) do
    {:error,
     %Error{
       code: :invalid_argument,
       operation: :source_enable,
       message: "version must be positive",
       procedure: name
     }}
  end

  def fetch_version(source, connection, name, version) do
    with :ok <- Validation.name(name),
         {:ok, table} <- table(source),
         true <- (is_integer(version) and version > 0) || invalid_version(name),
         {:ok, result} <-
           Tursox.Pool.query(
             connection,
             "SELECT #{@columns} FROM #{table} WHERE name = ? AND version = ?",
             [name, version]
           ) do
      one_result(result, name, false)
    end
  end

  @impl Tursox.Procedures.Source
  def fetch(source, connection, name) do
    with :ok <- Validation.name(name),
         {:ok, table} <- table(source),
         {:ok, result} <-
           Tursox.Pool.query(
             connection,
             "SELECT #{@columns} FROM #{table} WHERE name = ? ORDER BY enabled DESC, version DESC LIMIT 1",
             [name]
           ) do
      one_result(result, name, true)
    end
  end

  @impl Tursox.Procedures.Source
  def list(source, connection) do
    with {:ok, table} <- table(source),
         {:ok, %Tursox.Result{rows: rows}} <-
           Tursox.Pool.query(
             connection,
             "SELECT #{@columns} FROM #{table} WHERE enabled = 1 ORDER BY name",
             []
           ) do
      decode_rows(rows)
    else
      {:error, error} -> {:error, database_error(:source_list, error)}
    end
  end

  defp one_result(%Tursox.Result{rows: []}, name, _enabled), do: not_found(name)

  defp one_result(%Tursox.Result{rows: [row]}, name, require_enabled) do
    with {:ok, procedure} <- decode_row(row) do
      if require_enabled and not procedure.enabled do
        {:error,
         %Error{
           code: :disabled,
           operation: :source_fetch,
           message: "procedure is disabled",
           procedure: name
         }}
      else
        {:ok, procedure}
      end
    end
  end

  defp decode_rows(rows) do
    Enum.reduce_while(rows, {:ok, []}, fn row, {:ok, procedures} ->
      case decode_row(row) do
        {:ok, procedure} -> {:cont, {:ok, [procedure | procedures]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, procedures} -> {:ok, Enum.reverse(procedures)}
      error -> error
    end
  end

  defp decode_row([name, "lua", source, version, hash, enabled, metadata_json]) do
    with {:ok, metadata} <- Jason.decode(metadata_json),
         true <- hash == Validation.hash(source) || :invalid_hash do
      {:ok,
       %Procedure{
         name: name,
         language: :lua,
         source: source,
         version: version,
         source_hash: hash,
         enabled: enabled == 1,
         metadata: metadata
       }}
    else
      _ -> malformed(name)
    end
  end

  defp decode_row(row), do: malformed(inspect(row, limit: 0))

  defp encode_metadata(metadata) do
    case Jason.encode(metadata) do
      {:ok, json} ->
        {:ok, json}

      {:error, _} ->
        {:error,
         %Error{
           code: :invalid_argument,
           operation: :procedure_metadata,
           message: "metadata is not JSON-compatible"
         }}
    end
  end

  defp transaction(pool, fun) do
    case Tursox.Pool.transaction(
           pool,
           fn connection ->
             case fun.(connection) do
               {:error, error} -> DBConnection.rollback(connection, error)
               other -> other
             end
           end,
           mode: :immediate
         ) do
      {:ok, value} -> value
      {:error, %Error{} = error} -> {:error, error}
      {:error, error} -> {:error, database_error(:source_transaction, error)}
    end
  end

  defp execute(pool, sql, params) do
    case Tursox.Pool.execute(pool, sql, params) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, database_error(:source_execute, error)}
    end
  end

  defp table(options) when is_list(options),
    do: Validation.table(Keyword.get(options, :table, @default_table))

  defp table(%{table: table}), do: Validation.table(table)
  defp table(_source), do: Validation.table(@default_table)

  defp database_error(_operation, %Error{} = error), do: error

  defp database_error(operation, error),
    do: %Error{
      code: :database,
      operation: operation,
      message: "database operation failed",
      metadata: %{class: error.__struct__}
    }

  defp malformed(name),
    do:
      {:error,
       %Error{
         code: :internal,
         operation: :source_decode,
         message: "catalog row is invalid",
         procedure: to_string(name)
       }}

  defp not_found(name),
    do:
      {:error,
       %Error{
         code: :not_found,
         operation: :source_fetch,
         message: "procedure was not found",
         procedure: name
       }}

  defp invalid_version(name),
    do:
      {:error,
       %Error{
         code: :invalid_argument,
         operation: :source_fetch,
         message: "version must be positive",
         procedure: name
       }}
end
