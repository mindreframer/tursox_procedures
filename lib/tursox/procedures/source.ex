defmodule Tursox.Procedures.Source do
  @moduledoc "Source contract for resolving immutable procedure definitions."

  alias Tursox.Procedures.{Error, Procedure}

  @callback fetch(source :: term(), connection :: term(), name :: String.t()) ::
              {:ok, Procedure.t()} | {:error, Error.t()}

  @callback list(source :: term(), connection :: term()) ::
              {:ok, [Procedure.t()]} | {:error, Error.t()}
end
