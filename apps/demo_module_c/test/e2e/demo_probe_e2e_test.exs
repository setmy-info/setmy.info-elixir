defmodule SetmyInfo.DemoProbeE2ETest do
  @moduledoc """
  Smallest possible e2e-tier test. The tier runs against the release daemons
  brought up by the pre phase (see the umbrella's lifecycle.exs), so to run
  just this file:

      mix pre-e2e-test
      mix test apps/demo_module_c/test/e2e/demo_probe_e2e_test.exs --only e2e --no-start
      mix post-e2e-test
  """

  use ExUnit.Case, async: true

  @moduletag :e2e

  test "Probe" do
    message = "Hello World!"
    assert message == "Hello World!"
  end
end
