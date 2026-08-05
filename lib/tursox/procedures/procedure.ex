defmodule Tursox.Procedures.Procedure do
  @moduledoc "An immutable, versioned procedure definition."

  @enforce_keys [:name, :language, :source, :version, :source_hash]
  defstruct [:name, :language, :source, :version, :source_hash, enabled: true, metadata: %{}]

  @type t :: %__MODULE__{
          name: String.t(),
          language: :lua,
          source: String.t(),
          version: pos_integer(),
          source_hash: String.t(),
          enabled: boolean(),
          metadata: map()
        }

  @doc false
  def identity(%__MODULE__{} = procedure) do
    {procedure.name, procedure.version, procedure.source_hash}
  end
end

defimpl Inspect, for: Tursox.Procedures.Procedure do
  import Inspect.Algebra

  def inspect(procedure, opts) do
    safe = Map.take(procedure, [:name, :language, :version, :source_hash, :enabled])
    concat(["#Tursox.Procedures.Procedure<", to_doc(safe, opts), ">"])
  end
end
