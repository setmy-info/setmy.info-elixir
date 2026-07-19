defmodule SetmyInfo.DemoModuleD do
  @moduledoc """
  Module D - depends on c (which depends on a and b), the deepest node in
  the demo dependency graph: a,b -> c -> d.
  """

  require Logger

  alias SetmyInfo.DemoModuleC

  def create_message do
    "message from demo_module_d (#{DemoModuleC.create_message()})"
  end

  def foo do
    message = "foo() from demo_module_d"
    Logger.info(message)
    message
  end

  def create_descriptor do
    %{module: "d", message: create_message()}
  end
end
