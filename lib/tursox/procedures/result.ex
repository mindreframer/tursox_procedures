defmodule Tursox.Procedures.Result do
  @moduledoc "Successful procedure value and redacted immutable invocation trace."

  defstruct value: nil, trace: [], duration: 0

  @type trace_entry :: %{name: String.t(), version: pos_integer(), source_hash: String.t()}
  @type t :: %__MODULE__{value: term(), trace: [trace_entry()], duration: non_neg_integer()}
end
