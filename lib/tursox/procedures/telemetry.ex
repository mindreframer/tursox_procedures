defmodule Tursox.Procedures.Telemetry do
  @moduledoc "Redacted telemetry emitted by the procedure runtime."

  @prefix [:tursox_procedures]

  @doc false
  def execute(event, measurements, metadata) do
    :telemetry.execute(@prefix ++ List.wrap(event), measurements, metadata)
  end
end
