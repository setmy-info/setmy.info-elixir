defmodule SetmyInfo.DemoModuleC.EndpointServingTest do
    @moduledoc """
    The one guarantee `config/test.exs`' `serve: false` takes away from every
    other tier: that this app's own supervision tree really opens its endpoint
    when serving is on - what `iex -S mix` and `mix run --no-halt` rely on.
    Started by hand on a port of its own, so the release daemon on the
    configured port (which the e2e tier runs against) is untouched.

    Starting `c` also starts `a` and `b`, its umbrella siblings. They stay
    silent: `config/test.exs` leaves `serve: false` on both, so only the app
    under test here opens a port - the same arrangement `config/runtime.exs`
    makes inside a real release.
    """

    use ExUnit.Case, async: false

    @moduletag :integration

    @test_port 48_921

    test "the supervision tree serves priv/web when serve is on" do
        original_port = Application.fetch_env!(:demo_module_c, :port)
        Application.put_env(:demo_module_c, :port, @test_port)
        Application.put_env(:demo_module_c, :serve, true)

        on_exit(fn ->
            Application.stop(:demo_module_c)
            Application.put_env(:demo_module_c, :port, original_port)
            Application.put_env(:demo_module_c, :serve, false)
        end)

        {:ok, _apps} = Application.ensure_all_started(:demo_module_c)

        {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(~c"http://127.0.0.1:#{@test_port}/")

        assert String.contains?(to_string(body), "Module C web example")
    end
end
