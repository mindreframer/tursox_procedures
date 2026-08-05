defmodule Tursox.Procedures.Error do
  @moduledoc "Stable, redacted error returned by procedure operations."

  defexception [
    :code,
    :operation,
    :message,
    :procedure,
    :version,
    :line,
    procedure_stack: [],
    metadata: %{}
  ]

  @type code ::
          :not_found
          | :disabled
          | :invalid_argument
          | :compile_error
          | :runtime_error
          | :authorization
          | :database
          | :resource_limit
          | :timeout
          | :call_cycle
          | :call_depth
          | :transaction_failed
          | :internal

  @type t :: %__MODULE__{
          code: code(),
          operation: atom(),
          message: String.t(),
          procedure: String.t() | nil,
          version: pos_integer() | nil,
          line: pos_integer() | nil,
          procedure_stack: [map()],
          metadata: map()
        }

  @impl Exception
  def exception(opts) do
    struct!(__MODULE__, Keyword.put_new(opts, :message, "procedure operation failed"))
  end
end

defimpl Inspect, for: Tursox.Procedures.Error do
  import Inspect.Algebra

  def inspect(error, opts) do
    safe = Map.take(error, [:code, :operation, :message, :procedure, :version, :line])
    concat(["#Tursox.Procedures.Error<", to_doc(safe, opts), ">"])
  end
end
