defmodule SetmyInfo.DemoModuleBTest do
    use ExUnit.Case, async: true

    test "module b exposes its message" do
        assert SetmyInfo.DemoModuleB.create_message() == "message from demo_module_b"
        assert SetmyInfo.DemoModuleB.foo() == "foo() from demo_module_b"

        assert SetmyInfo.DemoModuleB.create_descriptor() == %{
                          module: "b",
                          message: "message from demo_module_b"
                      }
    end
end
