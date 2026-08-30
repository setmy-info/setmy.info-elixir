defmodule SetmyInfo.DemoModuleB.E2eTest do
    use ExUnit.Case, async: true

    @moduletag :e2e

    test "module b public API e2e" do
        assert SetmyInfo.DemoModuleB.create_message() == "message from demo_module_b"
        assert SetmyInfo.DemoModuleB.foo() == "foo() from demo_module_b"

        assert SetmyInfo.DemoModuleB.create_descriptor() == %{
                          module: "b",
                          message: "message from demo_module_b"
                      }
    end
end
