defmodule SetmyInfo.DemoModuleA.UnitTest do
    @moduledoc """
    Unit tier: this module's own pure functions, in process, with nothing
    started - no OTP application, no files, no environment, no network. `a` is
    the base app and depends on no sibling, so its whole public surface is
    reachable from here.

    What the other two tiers add for this app:
    `test/integration/` starts the real supervision tree and checks it serves;
    `test/e2e/` talks HTTP to the deployed OTP release from outside.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.DemoModuleA

    test "create_message/0 is the module's own message" do
        assert DemoModuleA.create_message() == "message from demo_module_a"
    end

    test "foo/0 returns what it logs" do
        assert DemoModuleA.foo() == "foo() from demo_module_a"
    end

    test "create_descriptor/0 names the module and carries its message" do
        assert DemoModuleA.create_descriptor() == %{
                 module: "a",
                 message: DemoModuleA.create_message()
               }
    end
end
