defmodule SetmyInfo.DemoModuleD.IntegrationTest do
    @moduledoc """
    Integration tier: `d` wired to the real `c`, and through it transitively to
    `a` and `b` - the deepest path in the demo dependency graph, a,b -> c -> d.

    The unit tier asserts d's own contract and deliberately stops there. What
    this tier adds is that the chain actually composes end to end, including
    the two apps `d` never names itself.
    """

    use ExUnit.Case, async: true

    @moduletag :integration

    alias SetmyInfo.DemoModuleA
    alias SetmyInfo.DemoModuleB
    alias SetmyInfo.DemoModuleC
    alias SetmyInfo.DemoModuleD

    test "the message embeds its direct dependency's message" do
        assert DemoModuleD.create_message() =~ DemoModuleC.create_message()
    end

    test "the transitive dependencies reach through c" do
        message = DemoModuleD.create_message()

        assert message =~ DemoModuleA.create_message()
        assert message =~ DemoModuleB.create_message()
    end

    test "the descriptor carries the composed message" do
        descriptor = DemoModuleD.create_descriptor()

        assert descriptor.module == "d"
        assert descriptor.message =~ DemoModuleC.create_message()
    end
end
