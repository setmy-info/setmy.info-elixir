defmodule SetmyInfo.DemoModuleC do
  @moduledoc """
  Module C - depends on a (unspecced) and b (specced), showing the two
  coexisting. c itself stays plain, and neither alias below needs to know or
  care that demo_module_b was written with Dialyzer specs.
  """

  require Logger

  alias SetmyInfo.DemoModuleA
  alias SetmyInfo.DemoModuleB

  @doc """
  Builds module c's greeting message, embedding the messages of a and b.
  """
  @spec create_message() :: String.t()
  def create_message do
    "message from demo_module_c (#{DemoModuleA.create_message()}, #{DemoModuleB.create_message()})"
  end

  @doc """
  Logs and returns module c's foo message.
  """
  @spec foo() :: String.t()
  def foo do
    message = "foo() from demo_module_c"
    Logger.info(message)
    message
  end

  @doc """
  Builds a descriptor map identifying module c and its message.
  """
  @spec create_descriptor() :: %{module: String.t(), message: String.t()}
  def create_descriptor do
    %{module: "c", message: create_message()}
  end
end
