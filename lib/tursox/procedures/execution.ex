defmodule Tursox.Procedures.Execution do
  @moduledoc false

  alias Tursox.Procedures.{Error, Limits}

  defmodule Handle do
    @moduledoc false
    @enforce_keys [:ref]
    defstruct [:ref]
  end

  def start(connection, options) do
    ref = make_ref()
    limits = Keyword.fetch!(options, :limits)
    now = System.monotonic_time(:millisecond)

    state = %{
      connection: connection,
      source: Keyword.fetch!(options, :source),
      cache: Keyword.fetch!(options, :cache),
      limits: limits,
      policy: Keyword.fetch!(options, :policy),
      caller: Keyword.get(options, :caller),
      duplicate_columns: Keyword.get(options, :duplicate_columns, :error),
      deadline: now + limits.timeout,
      counters: %{procedure_calls: 0, statements: 0, rows: 0, database_bytes: 0},
      stack: [],
      trace: [],
      failed: nil
    }

    Process.put(key(ref), state)
    %Handle{ref: ref}
  end

  def stop(%Handle{ref: ref}), do: Process.delete(key(ref))
  def state(%Handle{ref: ref}), do: Process.get(key(ref))

  def update(%Handle{ref: ref}, function) do
    current = Process.get(key(ref)) || raise "procedure execution context is unavailable"
    updated = function.(current)
    Process.put(key(ref), updated)
    updated
  end

  def fail(handle, %Error{} = error) do
    update(handle, fn state -> %{state | failed: state.failed || error} end)
    {:error, error}
  end

  def failed?(handle), do: state(handle).failed != nil
  def error(handle), do: state(handle).failed
  def trace(handle), do: Enum.reverse(state(handle).trace)
  def stack(handle), do: state(handle).stack

  def current_procedure(handle) do
    case state(handle).stack do
      [procedure | _] -> procedure
      [] -> nil
    end
  end

  def push(handle, procedure) do
    update(handle, fn state ->
      %{state | stack: [procedure | state.stack], trace: [trace_entry(procedure) | state.trace]}
    end)

    :ok
  end

  def pop(handle) do
    update(handle, fn
      %{stack: [_ | rest]} = state -> %{state | stack: rest}
      state -> state
    end)

    :ok
  end

  def check_deadline(handle) do
    if System.monotonic_time(:millisecond) <= state(handle).deadline do
      :ok
    else
      limit_error(handle, :timeout, :timeout, "procedure deadline exceeded")
    end
  end

  def charge(handle, counter, amount) when amount >= 0 do
    state = state(handle)
    limit = limit_for(state.limits, counter)
    value = Map.fetch!(state.counters, counter) + amount

    if value <= limit do
      update(handle, fn current -> put_in(current, [:counters, counter], value) end)
      :ok
    else
      limit_error(handle, :resource_limit, counter, "procedure #{counter} limit exceeded")
    end
  end

  def authorize(handle, operation, extra \\ %{}) do
    state = state(handle)
    procedure = current_procedure(handle)

    context =
      Map.merge(
        %{
          caller: state.caller,
          operation: operation,
          procedure: procedure && trace_entry(procedure),
          procedure_stack: Enum.map(state.stack, &trace_entry/1)
        },
        extra
      )

    result =
      case state.policy do
        module when is_atom(module) ->
          module.authorize(operation, context)

        {module, policy_options} ->
          module.authorize(operation, Map.put(context, :policy_options, policy_options))
      end

    case result do
      :ok ->
        :ok

      {:error, reason} ->
        error = %Error{
          code: :authorization,
          operation: operation,
          message: "procedure capability was denied",
          procedure: procedure && procedure.name,
          version: procedure && procedure.version,
          metadata: %{reason_class: reason_class(reason)}
        }

        fail(handle, error)

      _ ->
        error = %Error{
          code: :internal,
          operation: :policy,
          message: "procedure policy returned an invalid result"
        }

        fail(handle, error)
    end
  rescue
    _ ->
      error = %Error{code: :internal, operation: :policy, message: "procedure policy failed"}
      fail(handle, error)
  end

  defp limit_for(%Limits{} = limits, :procedure_calls), do: limits.max_procedure_calls
  defp limit_for(%Limits{} = limits, :statements), do: limits.max_statements
  defp limit_for(%Limits{} = limits, :rows), do: limits.max_rows
  defp limit_for(%Limits{} = limits, :database_bytes), do: limits.max_database_bytes

  defp limit_error(handle, code, operation, message) do
    procedure = current_procedure(handle)

    error = %Error{
      code: code,
      operation: operation,
      message: message,
      procedure: procedure && procedure.name,
      version: procedure && procedure.version
    }

    fail(handle, error)
  end

  defp trace_entry(procedure) do
    %{name: procedure.name, version: procedure.version, source_hash: procedure.source_hash}
  end

  defp reason_class(reason) when is_atom(reason), do: reason
  defp reason_class(%{__struct__: module}), do: module
  defp reason_class(_reason), do: :other

  defp key(ref), do: {__MODULE__, ref}
end
