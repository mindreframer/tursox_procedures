defmodule Tursox.Procedures do
  @moduledoc """
  Caller-supervised sandboxed, transactional Lua procedures for Tursox.

  A service owns configuration and a bounded compiled-chunk cache. Every call
  runs in an isolated process, checks out one Tursox transaction, and shares
  that transaction with all nested procedures.
  """

  use GenServer

  alias Tursox.Procedures.{Cache, Error, Limits, Runner, Telemetry}

  @call_options [:caller]

  @doc "Starts a procedure service."
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @doc false
  def child_spec(options) do
    %{
      id: Keyword.get(options, :id, Keyword.get(options, :name, __MODULE__)),
      start: {__MODULE__, :start_link, [Keyword.delete(options, :id)]},
      type: :worker
    }
  end

  @doc "Executes one named procedure and returns its value and immutable trace."
  def call(server, name, arguments \\ %{}, options \\ []) when is_list(options) do
    if Keyword.keyword?(options) and Keyword.keys(options) -- @call_options == [] do
      GenServer.call(server, {:call, name, arguments, options}, :infinity)
    else
      {:error,
       %Error{
         code: :invalid_argument,
         operation: :call,
         message: "call options support only :caller"
       }}
    end
  end

  @doc "Returns redacted service and cache metadata."
  def metadata(server), do: GenServer.call(server, :metadata)

  @doc "Drops compiled chunks; immutable source definitions are unaffected."
  def refresh(server), do: GenServer.call(server, :refresh)

  @doc "Stops the caller-owned service."
  def stop(server, timeout \\ 5_000), do: GenServer.stop(server, :normal, timeout)

  @impl true
  def init(options) do
    with {:ok, config} <- validate_options(options),
         {:ok, cache} <- Cache.start_link(capacity: config.cache_capacity) do
      {:ok, Map.merge(config, %{cache: cache, calls: %{}})}
    else
      {:error, %Error{} = error} -> {:stop, error}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call({:call, name, arguments, call_options}, from, state) do
    call_ref = make_ref()
    parent = self()
    started = System.monotonic_time()

    function = fn ->
      result =
        Runner.call(
          state.pool,
          state.source,
          state.cache,
          name,
          arguments,
          caller: Keyword.get(call_options, :caller),
          limits: state.limits,
          policy: state.policy,
          duplicate_columns: state.duplicate_columns,
          transaction_mode: state.transaction_mode
        )

      send(parent, {:procedure_result, call_ref, result, System.monotonic_time() - started})
    end

    {pid, monitor} =
      :erlang.spawn_opt(function, [
        :monitor,
        {:max_heap_size,
         %{
           size: max(div(state.limits.max_heap_size, :erlang.system_info(:wordsize)), 1_000),
           kill: true,
           error_logger: false
         }}
      ])

    timer = Process.send_after(self(), {:procedure_timeout, call_ref}, state.limits.timeout)

    call = %{
      from: from,
      pid: pid,
      monitor: monitor,
      timer: timer,
      name: safe_name(name),
      started: started
    }

    Telemetry.execute([:call, :start], %{system_time: System.system_time()}, %{
      procedure: safe_name(name)
    })

    {:noreply, put_in(state, [:calls, call_ref], call)}
  end

  def handle_call(:metadata, _from, state) do
    {:reply,
     %{
       active_calls: map_size(state.calls),
       cache: Cache.stats(state.cache),
       limits: state.limits,
       transaction_mode: state.transaction_mode
     }, state}
  end

  def handle_call(:refresh, _from, state), do: {:reply, Cache.clear(state.cache), state}

  @impl true
  def handle_info({:procedure_result, call_ref, result, duration}, state) do
    case Map.pop(state.calls, call_ref) do
      {nil, _calls} ->
        {:noreply, state}

      {call, calls} ->
        Process.cancel_timer(call.timer)
        Process.demonitor(call.monitor, [:flush])
        GenServer.reply(call.from, result)
        Telemetry.execute([:call, :stop], %{duration: duration}, call_metadata(call, result))
        {:noreply, %{state | calls: calls}}
    end
  end

  def handle_info({:procedure_timeout, call_ref}, state) do
    case Map.pop(state.calls, call_ref) do
      {nil, _calls} ->
        {:noreply, state}

      {call, calls} ->
        Process.exit(call.pid, :kill)

        error = %Error{
          code: :timeout,
          operation: :call,
          message: "procedure call timed out",
          procedure: call.name
        }

        GenServer.reply(call.from, {:error, error})

        Telemetry.execute(
          [:call, :stop],
          %{duration: System.monotonic_time() - call.started},
          call_metadata(call, {:error, error})
        )

        {:noreply, %{state | calls: calls}}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, reason}, state) do
    case Enum.find(state.calls, fn {_ref, call} -> call.monitor == monitor end) do
      nil ->
        {:noreply, state}

      {call_ref, call} ->
        Process.cancel_timer(call.timer)

        error = %Error{
          code: if(reason == :killed, do: :resource_limit, else: :internal),
          operation: :call,
          message:
            if(reason == :killed,
              do: "procedure process resource limit exceeded",
              else: "procedure process terminated"
            ),
          procedure: call.name,
          metadata: %{reason_class: reason_class(reason)}
        }

        GenServer.reply(call.from, {:error, error})

        Telemetry.execute(
          [:call, :stop],
          %{duration: System.monotonic_time() - call.started},
          call_metadata(call, {:error, error})
        )

        {:noreply, %{state | calls: Map.delete(state.calls, call_ref)}}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.calls, fn {_ref, call} -> Process.exit(call.pid, :kill) end)
    :ok
  end

  defp validate_options(options) do
    with pool when not is_nil(pool) <- Keyword.get(options, :pool),
         {source_module, _source_state} = source when is_atom(source_module) <-
           Keyword.get(options, :source),
         {:ok, limits} <- limits(Keyword.get(options, :limits, [])),
         {:ok, policy} <- policy(Keyword.get(options, :policy, Tursox.Procedures.Policy.AllowAll)),
         duplicate when duplicate in [:error, :first, :last] <-
           Keyword.get(options, :duplicate_columns, :error),
         mode when mode in [:deferred, :immediate, :exclusive, :concurrent] <-
           Keyword.get(options, :transaction_mode, :immediate),
         capacity when is_integer(capacity) and capacity > 0 <-
           Keyword.get(options, :cache_capacity, 128) do
      {:ok,
       %{
         pool: pool,
         source: source,
         limits: limits,
         policy: policy,
         duplicate_columns: duplicate,
         transaction_mode: mode,
         cache_capacity: capacity
       }}
    else
      {:error, %Error{} = error} ->
        {:error, error}

      _ ->
        {:error,
         invalid(
           "service requires valid :pool, :source, limits, policy, cache, and transaction options"
         )}
    end
  end

  defp limits(%Limits{} = limits), do: {:ok, limits}
  defp limits(options), do: Limits.new(options)

  defp policy(module) when is_atom(module), do: {:ok, module}
  defp policy({module, options}) when is_atom(module), do: {:ok, {module, options}}
  defp policy(_policy), do: {:error, invalid("policy must be a module or {module, options}")}

  defp invalid(message), do: %Error{code: :invalid_argument, operation: :start, message: message}
  defp safe_name(name) when is_binary(name), do: String.slice(name, 0, 128)
  defp safe_name(_name), do: nil
  defp reason_class(reason) when is_atom(reason), do: reason
  defp reason_class(_reason), do: :other

  defp call_metadata(call, result) do
    outcome =
      case result do
        {:ok, _} -> :ok
        {:error, %Error{code: code}} -> code
        _ -> :internal
      end

    %{procedure: call.name, outcome: outcome}
  end
end
