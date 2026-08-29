defmodule SetmyInfo.DemoModuleC do
  @moduledoc """
  Module C - depends on a (unspecced) and b (specced), showing the two
  coexisting. c itself stays plain, and neither alias below needs to know or
  care that demo_module_b was written with Dialyzer specs.
  """

  require Logger

  alias SetmyInfo.DemoModuleA
  alias SetmyInfo.DemoModuleB

  def create_message do
    "message from demo_module_c (#{DemoModuleA.create_message()}, #{DemoModuleB.create_message()})"
  end

  def foo do
    message = "foo() from demo_module_c"
    Logger.info(message)
    message
  end

  def create_descriptor do
    %{module: "c", message: create_message()}
  end
end
