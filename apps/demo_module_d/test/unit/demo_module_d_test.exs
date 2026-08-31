defmodule SetmyInfo.DemoModuleD.UnitTest do
    @moduledoc """
    Unit tier: what `d` itself contributes, in process, with nothing started.

    `d` wraps `c` (and so, transitively, `a` and `b`), and this tier
    deliberately does NOT assert what those put into the message - that is
    `test/integration/`'s job. Here the subject is d's own contract: its
    prefix, its `foo/0`, and the shape of its descriptor.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.DemoModuleD

    test "create_message/0 leads with the module's own message" do
        assert String.starts_with?(DemoModuleD.create_message(), "message from demo_module_d")
    end

    test "foo/0 returns what it logs" do
        assert DemoModuleD.foo() == "foo() from demo_module_d"
    end

    test "create_descriptor/0 names the module and carries its message" do
        assert DemoModuleD.create_descriptor() == %{
                 module: "d",
                 message: DemoModuleD.create_message()
               }
    end
end
