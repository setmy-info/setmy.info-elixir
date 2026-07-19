defmodule SetmyInfo.DemoModuleA do
  @moduledoc """
  Module A - base module in the umbrella dependency demo, no local
  dependencies.
  """

  require Logger

  @doc """
  Builds the greeting message published by demo_module_a.
  """
  def create_message do
    "message from demo_module_a"
  end

  @doc """
  Logs and returns module a's foo message.
  """
  def foo do
    message = "foo() from demo_module_a"
    Logger.info(message)
    message
  end

  @doc """
  Builds a descriptor map identifying module a and its message.
  """
  def create_descriptor do
    %{module: "a", message: create_message()}
  end
end
