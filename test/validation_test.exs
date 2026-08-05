defmodule Tursox.Procedures.ValidationTest do
  use ExUnit.Case, async: true

  alias Tursox.Procedures.Validation

  test "validates names, UTF-8 source, metadata, and source bounds" do
    assert {:ok, procedure} = Validation.procedure("注文.承認", "return true", %{"owner" => "tenant"})
    assert byte_size(procedure.source_hash) == 64

    for invalid <- ["", " spaced", "spaced ", "bad\0name", String.duplicate("x", 129)] do
      assert {:error, %Tursox.Procedures.Error{code: :invalid_argument}} =
               Validation.name(invalid)
    end

    assert {:error, %Tursox.Procedures.Error{code: :resource_limit}} =
             Validation.procedure("large", "return 1", %{}, 3)

    assert {:error, %Tursox.Procedures.Error{code: :invalid_argument}} =
             Validation.procedure("metadata", "return 1", %{pid: self()})
  end
end
