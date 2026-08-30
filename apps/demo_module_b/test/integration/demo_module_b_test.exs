defmodule SetmyInfo.DemoModuleB.IntegrationTest do
    @moduledoc """
    Integration tier: this tier only calls the public API the module exposes,
    the same contract a real caller gets, never reaching into internals the way
    a unit test may.
    """

    use ExUnit.Case, async: true

    @moduletag :integration

    test "module b public API" do
        assert SetmyInfo.DemoModuleB.create_message() == "message from demo_module_b"
        assert SetmyInfo.DemoModuleB.foo() == "foo() from demo_module_b"

        assert SetmyInfo.DemoModuleB.create_descriptor() == %{
                 module: "b",
                 message: "message from demo_module_b"
               }
    end
end
