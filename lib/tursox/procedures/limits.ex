defmodule Tursox.Procedures.Limits do
  @moduledoc "Finite resource limits applied to one complete procedure call tree."

  alias Tursox.Procedures.Error

  @fields [
    :timeout,
    :max_heap_size,
    :max_instructions,
    :max_lua_call_depth,
    :max_string_bytes,
    :max_source_bytes,
    :max_argument_bytes,
    :max_result_bytes,
    :max_procedure_depth,
    :max_procedure_calls,
    :max_statements,
    :max_rows,
    :max_database_bytes
  ]

  defstruct timeout: 5_000,
            max_heap_size: 64 * 1024 * 1024,
            max_instructions: 250_000,
            max_lua_call_depth: 64,
            max_string_bytes: 1_000_000,
            max_source_bytes: 256_000,
            max_argument_bytes: 1_000_000,
            max_result_bytes: 1_000_000,
            max_procedure_depth: 16,
            max_procedure_calls: 64,
            max_statements: 100,
            max_rows: 10_000,
            max_database_bytes: 16 * 1024 * 1024

  @type t :: %__MODULE__{}

  @doc "Builds finite limits from a keyword list or map."
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, Error.t()}
  def new(options \\ []) do
    options = if is_map(options), do: Map.to_list(options), else: options

    cond do
      not Keyword.keyword?(options) ->
        invalid("limits must be a keyword list or map")

      (unknown = Keyword.keys(options) -- @fields) != [] ->
        invalid("unknown limits: #{inspect(unknown)}")

      true ->
        build(options)
    end
  end

  defp build(options) do
    limits = struct!(__MODULE__, options)

    if Enum.all?(@fields, &(is_integer(Map.fetch!(limits, &1)) and Map.fetch!(limits, &1) > 0)) do
      {:ok, limits}
    else
      invalid("every limit must be a positive integer")
    end
  end

  defp invalid(message) do
    {:error, %Error{code: :invalid_argument, operation: :limits, message: message, metadata: %{}}}
  end
end
