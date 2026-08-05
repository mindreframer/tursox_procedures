defmodule Tursox.ProceduresTest do
  use ExUnit.Case, async: true

  test "loads the companion-package namespace" do
    assert Code.ensure_loaded?(Tursox.Procedures)
  end
end
