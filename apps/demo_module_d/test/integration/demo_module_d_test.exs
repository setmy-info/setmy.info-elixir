defmodule SetmyInfo.DemoModuleD.IntegrationTest do
    use ExUnit.Case, async: true

    @moduletag :integration

    test "module d public API" do
        message = SetmyInfo.DemoModuleD.create_message()
        assert message =~ "message from demo_module_c"
        assert SetmyInfo.DemoModuleD.foo() == "foo() from demo_module_d"
        assert SetmyInfo.DemoModuleD.create_descriptor() == %{module: "d", message: message}
    end
end
