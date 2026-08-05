defmodule Tursox.Procedures.TestSupport.SourceContract do
  @moduledoc false

  defmacro tests(build_source) do
    quote do
      test "publishes immutable versions and selects only the enabled version", context do
        source = unquote(build_source).(context)
        assert {:ok, first} = source.publish.("approve", "return 1", %{"owner" => "one"})
        assert first.version == 1
        assert {:ok, second} = source.publish.("approve", "return 2", %{"owner" => "two"})
        assert second.version == 2
        refute first.source_hash == second.source_hash
        assert {:ok, selected} = source.fetch.("approve")
        assert selected.version == 2
        assert selected.metadata == %{"owner" => "two"}
        assert :ok = source.disable.("approve")
        assert {:error, %Tursox.Procedures.Error{code: :disabled}} = source.fetch.("approve")
        assert :ok = source.enable.("approve", 1)
        assert {:ok, selected} = source.fetch.("approve")
        assert selected.version == 1
      end

      test "lists enabled procedures and distinguishes missing procedures", context do
        source = unquote(build_source).(context)
        assert {:ok, _} = source.publish.("b", "return 2", %{})
        assert {:ok, _} = source.publish.("a", "return 1", %{})
        assert {:ok, procedures} = source.list.()
        assert Enum.map(procedures, & &1.name) == ["a", "b"]
        assert {:error, %Tursox.Procedures.Error{code: :not_found}} = source.fetch.("missing")
      end
    end
  end
end
