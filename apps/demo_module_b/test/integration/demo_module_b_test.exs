defmodule SetmyInfo.DemoModuleB.IntegrationTest do
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
