defmodule SetmyInfo.DemoModuleD do
  @moduledoc """
  Module D - depends on c (which depends on a and b), the deepest node in
  the demo dependency graph: a,b -> c -> d.
  """

  require Logger

  alias SetmyInfo.DemoModuleC

  @doc """
  Builds module d's greeting message, embedding module c's message.
  """
  @spec create_message() :: String.t()
  def create_message do
    "message from demo_module_d (#{DemoModuleC.create_message()})"
  end

  @doc """
  Logs and returns module d's foo message.
  """
  @spec foo() :: String.t()
  def foo do
    message = "foo() from demo_module_d"
    Logger.info(message)
    message
  end

  @doc """
  Builds a descriptor map identifying module d and its message.
  """
  @spec create_descriptor() :: %{module: String.t(), message: String.t()}
  def create_descriptor do
    %{module: "d", message: create_message()}
  end
end
