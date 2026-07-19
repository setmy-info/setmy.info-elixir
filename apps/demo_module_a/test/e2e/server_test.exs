defmodule SetmyInfo.DemoModuleA.ServerTest do
  @moduledoc """
  §7.5: at least one e2e test makes a real request against the running
  instance started by `mix pre_e2e_test` (`mix server start --app
  demo_module_a`), not just re-imports the built code.
  """

  use ExUnit.Case, async: true

  test "e2e server serves the web page" do
    {:ok, {{_, 200, _}, _headers, body}} =
      :httpc.request(~c"http://127.0.0.1:48101/")

    assert String.contains?(to_string(body), "Module A web example")
  end
end
