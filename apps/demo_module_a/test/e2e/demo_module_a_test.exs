defmodule SetmyInfo.DemoModuleA.E2eTest do
    use ExUnit.Case, async: true

    @moduletag :e2e

    test "module a public API e2e" do
        assert SetmyInfo.DemoModuleA.create_message() == "message from demo_module_a"
        assert SetmyInfo.DemoModuleA.foo() == "foo() from demo_module_a"

        assert SetmyInfo.DemoModuleA.create_descriptor() == %{
                          module: "a",
                          message: "message from demo_module_a"
                      }
    end
end
