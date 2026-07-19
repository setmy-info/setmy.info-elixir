defmodule SetmyInfo.Build.ServerIntegrationTest do
  @moduledoc """
  Integration test for `mix server` - spawns it as a real subprocess (`mix
  server start`), makes a real HTTP request against a real listening
  server, then a real `mix server stop` subprocess. Not a unit test: real
  subprocess, real socket, real response (§7.7), mirroring the JS/Python
  sides' own http_server integration test.

  Uses demo_module_a (port 48_101, already configured in config/config.exs)
  rather than inventing a synthetic app - this is what actually exercises
  the real, already-configured code path.
  """

  use ExUnit.Case, async: false

  @port 48_101

  test "start, real HTTP request, stop" do
    root = Path.expand("../../../..", __DIR__)
    mix_bin = System.find_executable("mix")

    {_output, 0} = System.cmd(mix_bin, ["server", "start", "--app", "demo_module_a"], cd: root)

    {:ok, _} = Application.ensure_all_started(:inets)

    on_exit(fn ->
      System.cmd(mix_bin, ["server", "stop", "--app", "demo_module_a"], cd: root)
    end)

    {:ok, {{_, 200, _}, _headers, body}} =
      :httpc.request(~c"http://127.0.0.1:#{@port}/")

    assert String.contains?(to_string(body), "Module A web example")
  end
end
