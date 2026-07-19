defmodule SetmyInfo.DemoModuleCTest do
  use ExUnit.Case, async: true

  test "module c combines a and b" do
    message = SetmyInfo.DemoModuleC.create_message()
    assert message =~ "message from demo_module_a"
    assert message =~ "message from demo_module_b"
    assert SetmyInfo.DemoModuleC.foo() == "foo() from demo_module_c"
    assert SetmyInfo.DemoModuleC.create_descriptor() == %{module: "c", message: message}
  end
end
