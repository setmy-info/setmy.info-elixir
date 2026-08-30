defmodule SetmyInfo.DemoProbeTest do
    @moduledoc """
    Smallest possible unit-tier test. To run just this file:

        mix test apps/demo_module_c/test/unit/demo_probe_test.exs
    """

    use ExUnit.Case, async: true

    test "Probe" do
        message = "Hello World!"
        assert message == "Hello World!"
    end
end
