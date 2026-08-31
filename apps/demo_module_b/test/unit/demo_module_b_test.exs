defmodule SetmyInfo.DemoModuleB.UnitTest do
    @moduledoc """
    Unit tier: this module's own pure functions, in process, with nothing
    started - no OTP application, no files, no environment, no network. `b`
    depends on no sibling, so its whole public surface is reachable from here.
    It is the typed worked example of the umbrella: every function carries a
    `@spec`, and `mix dialyzer` is what checks those.

    What the other two tiers add for this app:
    `test/integration/` starts the real supervision tree and checks it serves;
    `test/e2e/` talks HTTP to the deployed OTP release from outside.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.DemoModuleB

    test "create_message/0 is the module's own message" do
        assert DemoModuleB.create_message() == "message from demo_module_b"
    end

    test "foo/0 returns what it logs" do
        assert DemoModuleB.foo() == "foo() from demo_module_b"
    end

    test "create_descriptor/0 names the module and carries its message" do
        assert DemoModuleB.create_descriptor() == %{
                 module: "b",
                 message: DemoModuleB.create_message()
               }
    end
end
