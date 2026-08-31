defmodule SetmyInfo.DemoModuleATest do
    use ExUnit.Case, async: true

    test "module a exposes its message" do
        assert SetmyInfo.DemoModuleA.create_message() == "message from demo_module_a"
        assert SetmyInfo.DemoModuleA.foo() == "foo() from demo_module_a"

        assert SetmyInfo.DemoModuleA.create_descriptor() == %{
                 module: "a",
                 message: "message from demo_module_a"
               }
    end
end
