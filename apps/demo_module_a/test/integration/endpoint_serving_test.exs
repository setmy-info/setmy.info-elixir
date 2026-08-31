defmodule SetmyInfo.DemoModuleA.EndpointServingTest do
    @moduledoc """
    The one guarantee `config/test.exs`' `serve: false` takes away from every
    other tier: that this app's own supervision tree really opens its endpoint
    when serving is on - what `iex -S mix` and `mix run --no-halt` rely on.
    Started by hand on a port of its own, so the release daemon on the
    configured port (which this tier runs against) is untouched.
    """

    use ExUnit.Case, async: false

    @moduletag :integration

    @test_port 48_901

    test "the supervision tree serves priv/web when serve is on" do
        original_port = Application.fetch_env!(:demo_module_a, :port)
        Application.put_env(:demo_module_a, :port, @test_port)
        Application.put_env(:demo_module_a, :serve, true)

        on_exit(fn ->
            Application.stop(:demo_module_a)
            Application.put_env(:demo_module_a, :port, original_port)
            Application.put_env(:demo_module_a, :serve, false)
        end)

        {:ok, _apps} = Application.ensure_all_started(:demo_module_a)

        {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(~c"http://127.0.0.1:#{@test_port}/")

        assert String.contains?(to_string(body), "Module A web example")
    end
end
