defmodule Tursox.Procedures.Source.Memory do
  @moduledoc "Caller-supervised in-memory procedure source for tests and dynamic applications."

  use GenServer
  @behaviour Tursox.Procedures.Source

  alias Tursox.Procedures.{Error, Procedure, Validation}

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  def child_spec(options) do
    %{id: Keyword.get(options, :id, __MODULE__), start: {__MODULE__, :start_link, [options]}}
  end

  def publish(source, name, code, metadata \\ %{}, options \\ []) do
    with {:ok, procedure} <-
           Validation.procedure(
             name,
             code,
             metadata,
             Keyword.get(options, :max_source_bytes, 256_000)
           ) do
      GenServer.call(source, {:publish, procedure})
    end
  end

  def disable(source, name), do: GenServer.call(source, {:disable, name})
  def enable(source, name, version), do: GenServer.call(source, {:enable, name, version})

  def fetch_version(source, name, version),
    do: GenServer.call(source, {:fetch_version, name, version})

  @impl Tursox.Procedures.Source
  def fetch(source, _connection, name) do
    with :ok <- Validation.name(name) do
      GenServer.call(source, {:fetch, name})
    end
  end

  @impl Tursox.Procedures.Source
  def list(source, _connection), do: GenServer.call(source, :list)

  @impl GenServer
  def init(options) do
    initial = Keyword.get(options, :procedures, [])

    Enum.reduce_while(initial, {:ok, %{}}, fn definition, {:ok, state} ->
      with {name, code, metadata} <- normalize_definition(definition),
           {:ok, procedure} <- Validation.procedure(name, code, metadata) do
        {:cont, {:ok, Map.put(state, name, [procedure])}}
      else
        _ -> {:halt, {:stop, :invalid_initial_procedure}}
      end
    end)
  end

  @impl GenServer
  def handle_call({:publish, procedure}, _from, state) do
    versions = Map.get(state, procedure.name, [])
    version = versions |> Enum.map(& &1.version) |> Enum.max(fn -> 0 end) |> Kernel.+(1)
    disabled = Enum.map(versions, &%{&1 | enabled: false})
    published = %{procedure | version: version}
    {:reply, {:ok, published}, Map.put(state, procedure.name, [published | disabled])}
  end

  def handle_call({:fetch, name}, _from, state) do
    reply =
      state
      |> Map.get(name, [])
      |> Enum.find(& &1.enabled)
      |> case do
        %Procedure{} = procedure -> {:ok, procedure}
        nil -> missing_or_disabled(state, name)
      end

    {:reply, reply, state}
  end

  def handle_call({:fetch_version, name, version}, _from, state) do
    reply =
      case Enum.find(Map.get(state, name, []), &(&1.version == version)) do
        nil -> not_found(name)
        procedure -> {:ok, procedure}
      end

    {:reply, reply, state}
  end

  def handle_call({:disable, name}, _from, state) do
    case Map.fetch(state, name) do
      :error ->
        {:reply, not_found(name), state}

      {:ok, versions} ->
        {:reply, :ok, Map.put(state, name, Enum.map(versions, &%{&1 | enabled: false}))}
    end
  end

  def handle_call({:enable, name, version}, _from, state) do
    versions = Map.get(state, name, [])

    if Enum.any?(versions, &(&1.version == version)) do
      updated = Enum.map(versions, &%{&1 | enabled: &1.version == version})
      {:reply, :ok, Map.put(state, name, updated)}
    else
      {:reply, not_found(name), state}
    end
  end

  def handle_call(:list, _from, state) do
    procedures =
      state
      |> Map.values()
      |> List.flatten()
      |> Enum.filter(& &1.enabled)
      |> Enum.sort_by(& &1.name)

    {:reply, {:ok, procedures}, state}
  end

  defp normalize_definition({name, code}), do: {name, code, %{}}
  defp normalize_definition({name, code, metadata}), do: {name, code, metadata}

  defp normalize_definition(%{name: name, source: code} = map),
    do: {name, code, Map.get(map, :metadata, %{})}

  defp normalize_definition(_definition), do: :error

  defp missing_or_disabled(state, name) do
    if Map.has_key?(state, name) do
      {:error,
       %Error{
         code: :disabled,
         operation: :source_fetch,
         message: "procedure is disabled",
         procedure: name
       }}
    else
      not_found(name)
    end
  end

  defp not_found(name) do
    {:error,
     %Error{
       code: :not_found,
       operation: :source_fetch,
       message: "procedure was not found",
       procedure: name
     }}
  end
end
