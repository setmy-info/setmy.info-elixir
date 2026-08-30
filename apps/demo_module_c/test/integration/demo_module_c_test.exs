defmodule SetmyInfo.DemoModuleC.IntegrationTest do
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
