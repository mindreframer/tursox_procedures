defmodule Tursox.Procedures.MemorySourceTest do
  use ExUnit.Case, async: true

  alias Tursox.Procedures.Source.Memory
  require Tursox.Procedures.TestSupport.SourceContract

  Tursox.Procedures.TestSupport.SourceContract.tests(fn context ->
    source = context.memory_source

    %{
      publish: &Memory.publish(source, &1, &2, &3),
      fetch: &Memory.fetch(source, nil, &1),
      list: fn -> Memory.list(source, nil) end,
      disable: &Memory.disable(source, &1),
      enable: &Memory.enable(source, &1, &2)
    }
  end)

  setup do
    source = start_supervised!({Memory, id: make_ref()})
    %{memory_source: source}
  end
end
