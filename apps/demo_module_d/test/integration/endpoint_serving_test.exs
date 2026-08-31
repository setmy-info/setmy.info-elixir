defmodule SetmyInfo.DemoModuleD.EndpointServingTest do
    @moduledoc """
    The one guarantee `config/test.exs`' `serve: false` takes away from every
    other tier: that this app's own supervision tree really opens its endpoint
    when serving is on - what `iex -S mix` and `mix run --no-halt` rely on.
    Started by hand on a port of its own, so the release daemon on the
    configured port (which the e2e tier runs against) is untouched.

    Starting `d` also starts `c`, and through it `a` and `b`. They stay
    silent: `config/test.exs` leaves `serve: false` on all three, so only the
    app under test here opens a port - the same arrangement
    `config/runtime.exs` makes inside a real release.
    """

    use ExUnit.Case, async: false

    @moduletag :integration

    @test_port 48_931

    test "the supervision tree serves priv/web when serve is on" do
        original_port = Application.fetch_env!(:demo_module_d, :port)
        Application.put_env(:demo_module_d, :port, @test_port)
        Application.put_env(:demo_module_d, :serve, true)

        on_exit(fn ->
            Application.stop(:demo_module_d)
            Application.put_env(:demo_module_d, :port, original_port)
            Application.put_env(:demo_module_d, :serve, false)
        end)

        {:ok, _apps} = Application.ensure_all_started(:demo_module_d)

        {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(~c"http://127.0.0.1:#{@test_port}/")

        assert String.contains?(to_string(body), "Module D web example")
    end
end
