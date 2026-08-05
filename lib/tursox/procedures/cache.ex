defmodule Tursox.Procedures.Cache do
  @moduledoc "Bounded immutable compiled-procedure cache."

  use GenServer

  alias Tursox.Procedures.{Error, Procedure, Telemetry, Validation}

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  def child_spec(options) do
    %{id: Keyword.get(options, :id, __MODULE__), start: {__MODULE__, :start_link, [options]}}
  end

  def fetch(cache, %Procedure{} = procedure),
    do: GenServer.call(cache, {:fetch, procedure}, 30_000)

  def stats(cache), do: GenServer.call(cache, :stats)
  def clear(cache), do: GenServer.call(cache, :clear)

  @impl true
  def init(options) do
    capacity = Keyword.get(options, :capacity, 128)

    if is_integer(capacity) and capacity > 0 do
      {:ok, %{capacity: capacity, entries: %{}, tick: 0, hits: 0, misses: 0, evictions: 0}}
    else
      {:stop, :invalid_capacity}
    end
  end

  @impl true
  def handle_call({:fetch, procedure}, _from, state) do
    identity = Procedure.identity(procedure)
    tick = state.tick + 1

    case Map.fetch(state.entries, identity) do
      {:ok, {chunk, _last_tick}} ->
        entries = Map.put(state.entries, identity, {chunk, tick})
        Telemetry.execute([:cache, :stop], %{count: 1}, cache_metadata(procedure, :hit))
        {:reply, {:ok, chunk}, %{state | entries: entries, tick: tick, hits: state.hits + 1}}

      :error ->
        case compile(procedure) do
          {:ok, chunk} ->
            {entries, evicted?} =
              put_bounded(state.entries, identity, chunk, tick, state.capacity)

            Telemetry.execute([:cache, :stop], %{count: 1}, cache_metadata(procedure, :miss))

            {:reply, {:ok, chunk},
             %{
               state
               | entries: entries,
                 tick: tick,
                 misses: state.misses + 1,
                 evictions: state.evictions + if(evicted?, do: 1, else: 0)
             }}

          {:error, error} ->
            Telemetry.execute([:cache, :stop], %{count: 1}, cache_metadata(procedure, error.code))
            {:reply, {:error, error}, %{state | tick: tick, misses: state.misses + 1}}
        end
    end
  end

  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       size: map_size(state.entries),
       capacity: state.capacity,
       hits: state.hits,
       misses: state.misses,
       evictions: state.evictions
     }, state}
  end

  def handle_call(:clear, _from, state), do: {:reply, :ok, %{state | entries: %{}}}

  defp compile(%Procedure{} = procedure) do
    cond do
      procedure.source_hash != Validation.hash(procedure.source) ->
        {:error,
         %Error{
           code: :internal,
           operation: :compile,
           message: "procedure source hash does not match source",
           procedure: procedure.name,
           version: procedure.version
         }}

      true ->
        case Lua.parse_chunk(procedure.source) do
          {:ok, chunk} ->
            {:ok, chunk}

          {:error, exception} ->
            {:error,
             %Error{
               code: :compile_error,
               operation: :compile,
               message: "Lua source did not compile",
               procedure: procedure.name,
               version: procedure.version,
               line: exception_line(exception)
             }}
        end
    end
  rescue
    _exception ->
      {:error,
       %Error{
         code: :compile_error,
         operation: :compile,
         message: "Lua source did not compile",
         procedure: procedure.name,
         version: procedure.version
       }}
  end

  defp put_bounded(entries, identity, chunk, tick, capacity) do
    entries = Map.put(entries, identity, {chunk, tick})

    if map_size(entries) <= capacity do
      {entries, false}
    else
      {oldest, _value} = Enum.min_by(entries, fn {_identity, {_chunk, used}} -> used end)
      {Map.delete(entries, oldest), true}
    end
  end

  defp cache_metadata(procedure, outcome) do
    %{
      procedure: procedure.name,
      version: procedure.version,
      source_hash: procedure.source_hash,
      outcome: outcome
    }
  end

  defp exception_line(exception) do
    case Map.get(exception, :line) do
      line when is_integer(line) and line > 0 -> line
      _ -> nil
    end
  end
end
