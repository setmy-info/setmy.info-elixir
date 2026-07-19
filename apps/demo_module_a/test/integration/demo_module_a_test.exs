defmodule SetmyInfo.DemoModuleA.IntegrationTest do
  @moduledoc """
  Integration tier (§7.3: against the built artifact, not source directly).
  Documented divergence from the JS/Python sides too (same reasoning as
  Python's report.md): Elixir has no transpile/bundle step producing a
  meaningfully different "built" artifact - the compiled module *is* the
  source. The distinction kept here instead: this tier only calls the
  public API the module exposes, the same contract a real caller gets,
  never reaching into private functions the way a unit test may.
  """

  use ExUnit.Case, async: true

  test "module a public API" do
    assert SetmyInfo.DemoModuleA.create_message() == "message from demo_module_a"
    assert SetmyInfo.DemoModuleA.foo() == "foo() from demo_module_a"

    assert SetmyInfo.DemoModuleA.create_descriptor() == %{
             module: "a",
             message: "message from demo_module_a"
           }
  end
end
