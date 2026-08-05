defmodule Tursox.Procedures.LuaAPI.Core do
  @moduledoc false

  use Lua.API

  deflua fail(code, message) when is_binary(code) and is_binary(message) do
    runtime_exception!("__tursox_fail__" <> code <> "\0" <> message)
  end

  deflua fail(_code, _message) do
    runtime_exception!("__tursox_fail__invalid_failure\0code and message must be strings")
  end
end
