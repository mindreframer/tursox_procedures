defmodule Tursox.Procedures.Validation do
  @moduledoc false

  alias Tursox.Procedures.{Error, Procedure}

  @name_max 128

  def procedure(name, source, metadata, max_source_bytes \\ 256_000) do
    with :ok <- name(name),
         :ok <- source(source, max_source_bytes),
         :ok <- metadata(metadata) do
      {:ok,
       %Procedure{
         name: name,
         language: :lua,
         source: source,
         version: 1,
         source_hash: hash(source),
         metadata: metadata,
         enabled: true
       }}
    end
  end

  def name(name) when is_binary(name) do
    cond do
      name == "" ->
        invalid(:procedure_name, "procedure name must not be empty")

      byte_size(name) > @name_max ->
        invalid(:procedure_name, "procedure name is too long")

      not String.valid?(name) ->
        invalid(:procedure_name, "procedure name must be valid UTF-8")

      String.trim(name) != name ->
        invalid(:procedure_name, "procedure name must not have surrounding whitespace")

      String.contains?(name, <<0>>) ->
        invalid(:procedure_name, "procedure name must not contain NUL")

      String.match?(name, ~r/[\p{Cc}\p{Cf}]/u) ->
        invalid(:procedure_name, "procedure name must not contain control characters")

      true ->
        :ok
    end
  end

  def name(_name), do: invalid(:procedure_name, "procedure name must be a string")

  def source(source, max_bytes)
      when is_binary(source) and is_integer(max_bytes) and max_bytes > 0 do
    cond do
      source == "" ->
        invalid(:procedure_source, "procedure source must not be empty")

      not String.valid?(source) ->
        invalid(:procedure_source, "procedure source must be valid UTF-8")

      byte_size(source) > max_bytes ->
        limit(:procedure_source, "procedure source exceeds the configured limit")

      true ->
        :ok
    end
  end

  def source(_source, _max_bytes),
    do: invalid(:procedure_source, "procedure source must be a string")

  def metadata(metadata) when is_map(metadata) do
    case Jason.encode(metadata) do
      {:ok, _json} ->
        :ok

      {:error, _error} ->
        invalid(:procedure_metadata, "procedure metadata must be JSON-compatible")
    end
  end

  def metadata(_metadata), do: invalid(:procedure_metadata, "procedure metadata must be a map")

  def hash(source), do: :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)

  def table(table) when is_binary(table) do
    if Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_]{0,62}$/, table) do
      {:ok, table}
    else
      invalid(:catalog, "catalog table must be a simple SQL identifier")
    end
  end

  def table(_table), do: invalid(:catalog, "catalog table must be a string")

  defp invalid(operation, message) do
    {:error, %Error{code: :invalid_argument, operation: operation, message: message}}
  end

  defp limit(operation, message) do
    {:error, %Error{code: :resource_limit, operation: operation, message: message}}
  end
end
