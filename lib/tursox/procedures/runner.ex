defmodule Tursox.Procedures.Runner do
  @moduledoc false

  alias Tursox.Procedures.{Error, Execution, Limits, Result, Runtime, Validation}

  def call(pool, source, cache, name, arguments, options \\ []) do
    started = System.monotonic_time()

    with :ok <- Validation.name(name),
         {:ok, limits} <- limits(options),
         {:ok, policy} <- policy(options),
         {:ok, duplicate_columns} <- duplicate_columns(options) do
      transaction_result =
        Tursox.Pool.transaction(
          pool,
          fn connection ->
            handle =
              Execution.start(connection,
                source: source,
                cache: cache,
                limits: limits,
                policy: policy,
                caller: Keyword.get(options, :caller),
                duplicate_columns: duplicate_columns
              )

            try do
              case run_one(handle, name, arguments) do
                {:ok, value} ->
                  if Execution.failed?(handle) do
                    DBConnection.rollback(connection, Execution.error(handle))
                  else
                    {:ok, value, Execution.trace(handle)}
                  end

                {:error, error} ->
                  DBConnection.rollback(connection, error)
              end
            after
              Execution.stop(handle)
            end
          end,
          mode: Keyword.get(options, :transaction_mode, :immediate),
          timeout: limits.timeout
        )

      finish(transaction_result, started)
    end
  rescue
    exception ->
      {:error,
       %Error{
         code: :internal,
         operation: :call,
         message: "procedure call failed internally",
         procedure: name,
         metadata: %{class: exception.__struct__}
       }}
  catch
    :exit, _reason ->
      {:error,
       %Error{
         code: :timeout,
         operation: :call,
         message: "procedure call timed out",
         procedure: name
       }}
  end

  def run_one(handle, name, arguments) do
    state = Execution.state(handle)
    {source_module, source_state} = state.source

    with :ok <- Execution.check_deadline(handle),
         :ok <- Execution.charge(handle, :procedure_calls, 1),
         {:ok, procedure} <- source_module.fetch(source_state, state.connection, name),
         :ok <- Execution.authorize(handle, :call, %{callee: trace_entry(procedure)}) do
      Execution.push(handle, procedure)

      try do
        case Runtime.execute(state.cache, procedure, arguments, handle, state.limits) do
          {:ok, value} -> {:ok, value}
          {:error, error} -> Execution.fail(handle, decorate_error(error, handle))
        end
      after
        Execution.pop(handle)
      end
    else
      {:error, %Error{} = error} -> Execution.fail(handle, decorate_error(error, handle))
      {:error, error} -> Execution.fail(handle, database_error(error, name))
    end
  end

  defp finish({:ok, {:ok, value, trace}}, started) do
    {:ok,
     %Result{
       value: value,
       trace: trace,
       duration: System.monotonic_time() - started
     }}
  end

  defp finish({:error, %Error{} = error}, _started), do: {:error, error}
  defp finish({:error, error}, _started), do: {:error, database_error(error, nil)}

  defp finish(other, _started),
    do:
      {:error,
       %Error{
         code: :internal,
         operation: :transaction,
         message: "transaction returned an invalid result",
         metadata: %{shape: shape(other)}
       }}

  defp limits(options) do
    case Keyword.get(options, :limits, []) do
      %Limits{} = limits -> {:ok, limits}
      values -> Limits.new(values)
    end
  end

  defp policy(options) do
    policy = Keyword.get(options, :policy, Tursox.Procedures.Policy.AllowAll)

    case policy do
      module when is_atom(module) ->
        {:ok, module}

      {module, policy_options} when is_atom(module) ->
        {:ok, {module, policy_options}}

      _ ->
        {:error,
         %Error{
           code: :invalid_argument,
           operation: :policy,
           message: "policy must be a module or {module, options}"
         }}
    end
  end

  defp duplicate_columns(options) do
    case Keyword.get(options, :duplicate_columns, :error) do
      policy when policy in [:error, :first, :last] ->
        {:ok, policy}

      _ ->
        {:error,
         %Error{
           code: :invalid_argument,
           operation: :call,
           message: "duplicate_columns must be :error, :first, or :last"
         }}
    end
  end

  defp decorate_error(%Error{} = error, handle) do
    stack = Enum.map(Execution.stack(handle), &trace_entry/1)
    %{error | procedure_stack: stack}
  end

  defp database_error(error, name) do
    %Error{
      code: :database,
      operation: :transaction,
      message: "database transaction failed",
      procedure: name,
      metadata: %{class: error_class(error)}
    }
  end

  defp error_class(%{code: code}) when is_atom(code), do: code
  defp error_class(%{__struct__: module}), do: module
  defp error_class(_error), do: :other
  defp shape(value) when is_tuple(value), do: {:tuple, tuple_size(value)}
  defp shape(value) when is_atom(value), do: value
  defp shape(_value), do: :other

  defp trace_entry(procedure),
    do: %{name: procedure.name, version: procedure.version, source_hash: procedure.source_hash}
end
