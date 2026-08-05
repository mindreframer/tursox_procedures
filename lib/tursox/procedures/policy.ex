defmodule Tursox.Procedures.Policy do
  @moduledoc "Authorization boundary for procedure and database capabilities."

  @type operation :: :call | :query | :execute
  @callback authorize(operation(), map()) :: :ok | {:error, term()}
end

defmodule Tursox.Procedures.Policy.AllowAll do
  @moduledoc "Explicit policy for trusted procedure authors with full database access."
  @behaviour Tursox.Procedures.Policy

  @impl true
  def authorize(_operation, _context), do: :ok
end
