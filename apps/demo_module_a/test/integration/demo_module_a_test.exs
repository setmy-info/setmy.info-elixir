defmodule SetmyInfo.DemoModuleA.IntegrationTest do
  @moduledoc """
  Integration tier: this tier only calls the public API the module exposes,
  the same contract a real caller gets, never reaching into internals the way
  a unit test may.
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  test "module a public API" do
    assert SetmyInfo.DemoModuleA.create_message() == "message from demo_module_a"
    assert SetmyInfo.DemoModuleA.foo() == "foo() from demo_module_a"

    assert SetmyInfo.DemoModuleA.create_descriptor() == %{
             module: "a",
             message: "message from demo_module_a"
           }
  end
end
