defmodule Tursox.Procedures.FoundationTest do
  use ExUnit.Case, async: true

  alias Tursox.Procedures.{Error, Limits, Procedure}

  test "finite limits validate strictly" do
    assert {:ok, %Limits{timeout: 10}} = Limits.new(timeout: 10)
    assert {:error, %Error{code: :invalid_argument}} = Limits.new(timeout: :infinity)
    assert {:error, %Error{code: :invalid_argument}} = Limits.new(unknown: 1)
  end

  test "procedure and errors redact source, metadata, and stack details from inspect" do
    procedure = %Procedure{
      name: "approve_order",
      language: :lua,
      source: "secret-source",
      version: 1,
      source_hash: String.duplicate("a", 64),
      metadata: %{"token" => "secret-token"}
    }

    error = %Error{
      code: :runtime_error,
      operation: :execute,
      message: "safe",
      procedure: "approve_order",
      procedure_stack: [%{arguments: "secret-arguments"}],
      metadata: %{source: "secret-source"}
    }

    refute inspect(procedure) =~ "secret-source"
    refute inspect(procedure) =~ "secret-token"
    refute inspect(error) =~ "secret-arguments"
    refute inspect(error) =~ "secret-source"
  end
end
