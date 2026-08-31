defmodule SetmyInfo.DemoModuleC.UnitTest do
    @moduledoc """
    Unit tier: what `c` itself contributes, in process, with nothing started.

    `c` composes `a` and `b`, and this tier deliberately does NOT assert what
    those two put into the message - that is `test/integration/`'s job, which
    is the tier that exists to check apps wired together. Here the subject is
    c's own contract: its prefix, its `foo/0`, and the shape of its
    descriptor. Written this way the tier keeps its meaning without needing a
    mocking library to cut the siblings out.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.DemoModuleC

    test "create_message/0 leads with the module's own message" do
        assert String.starts_with?(DemoModuleC.create_message(), "message from demo_module_c")
    end

    test "foo/0 returns what it logs" do
        assert DemoModuleC.foo() == "foo() from demo_module_c"
    end

    test "create_descriptor/0 names the module and carries its message" do
        assert DemoModuleC.create_descriptor() == %{
                 module: "c",
                 message: DemoModuleC.create_message()
               }
    end
end
