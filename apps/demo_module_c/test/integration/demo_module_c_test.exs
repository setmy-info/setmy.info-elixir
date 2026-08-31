defmodule SetmyInfo.DemoModuleC.IntegrationTest do
    @moduledoc """
    Integration tier: `c` wired to the real `a` and `b`, which is the thing
    this app exists to demonstrate - an umbrella sibling dependency, and typed
    (`b`, fully specced) and untyped (`a`) code composing without either
    knowing about the other.

    The unit tier asserts c's own contract and deliberately stops there; the
    sibling content below is what only this tier can see. No mocks: the
    siblings are real, which is the whole point of the tier.
    """

    use ExUnit.Case, async: true

    @moduletag :integration

    alias SetmyInfo.DemoModuleA
    alias SetmyInfo.DemoModuleB
    alias SetmyInfo.DemoModuleC

    test "the message embeds both siblings' own messages" do
        message = DemoModuleC.create_message()

        assert message =~ DemoModuleA.create_message()
        assert message =~ DemoModuleB.create_message()
    end

    test "a sibling's message is embedded as that sibling reports it, not copied" do
        # If `a` changed its wording, `c` would follow: nothing here restates
        # the sibling's string, so this cannot drift out of date.
        assert DemoModuleC.create_message() =~ "message from demo_module_a"
        assert DemoModuleA.create_message() == "message from demo_module_a"
    end

    test "the descriptor carries the composed message" do
        descriptor = DemoModuleC.create_descriptor()

        assert descriptor.module == "c"
        assert descriptor.message =~ DemoModuleA.create_message()
        assert descriptor.message =~ DemoModuleB.create_message()
    end
end
