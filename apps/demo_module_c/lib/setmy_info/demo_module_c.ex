defmodule SetmyInfo.DemoModuleC do
  @moduledoc """
  Module C - depends on a (untyped) and b (typed): §9.4's coexistence proof.
  c itself stays plain/unchecked, and neither import below needs to know or
  care that demo_module_b was written with Dialyzer specs (§9.3).
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
