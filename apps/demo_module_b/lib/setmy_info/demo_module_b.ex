defmodule SetmyInfo.DemoModuleB do
  @moduledoc """
  Module B - the typed worked example: full `@spec` coverage, checked by
  `mix dialyzer` like every other app in the umbrella. Downstream apps (c, d
  - plain, unspecced) consume it exactly like any other app: they never need
  to know or care it was written with specs.
  """

  require Logger

  @type descriptor :: %{module: String.t(), message: String.t()}

  @spec create_message() :: String.t()
  def create_message do
    "message from demo_module_b"
  end

  @spec foo() :: String.t()
  def foo do
    message = "foo() from demo_module_b"
    Logger.info(message)
    message
  end

  @spec create_descriptor() :: descriptor()
  def create_descriptor do
    %{module: "b", message: create_message()}
  end
end
