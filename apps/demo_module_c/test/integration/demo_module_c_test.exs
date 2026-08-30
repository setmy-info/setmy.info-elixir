defmodule SetmyInfo.DemoModuleC.IntegrationTest do
    @moduledoc """
    Integration tier: this tier only calls the public API the module exposes,
    the same contract a real caller gets, never reaching into internals the way
    a unit test may.
    """

    use ExUnit.Case, async: true

    @moduletag :integration

    test "module c public API" do
        message = SetmyInfo.DemoModuleC.create_message()
        assert message =~ "message from demo_module_a"
        assert message =~ "message from demo_module_b"
        assert SetmyInfo.DemoModuleC.foo() == "foo() from demo_module_c"
        assert SetmyInfo.DemoModuleC.create_descriptor() == %{module: "c", message: message}
    end
end
