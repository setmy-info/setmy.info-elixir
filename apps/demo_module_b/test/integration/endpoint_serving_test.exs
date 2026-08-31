defmodule SetmyInfo.DemoModuleB.EndpointServingTest do
    @moduledoc """
    The one guarantee `config/test.exs`' `serve: false` takes away from every
    other tier: that this app's own supervision tree really opens its endpoint
    when serving is on - what `iex -S mix` and `mix run --no-halt` rely on.
    Started by hand on a port of its own, so the release daemon on the
    configured port (which the e2e tier runs against) is untouched.
    """

    use ExUnit.Case, async: false

    @moduletag :integration

    @test_port 48_911

    test "the supervision tree serves priv/web when serve is on" do
        original_port = Application.fetch_env!(:demo_module_b, :port)
        Application.put_env(:demo_module_b, :port, @test_port)
        Application.put_env(:demo_module_b, :serve, true)

        on_exit(fn ->
            Application.stop(:demo_module_b)
            Application.put_env(:demo_module_b, :port, original_port)
            Application.put_env(:demo_module_b, :serve, false)
        end)

        {:ok, _apps} = Application.ensure_all_started(:demo_module_b)

        {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(~c"http://127.0.0.1:#{@test_port}/")

        assert String.contains?(to_string(body), "Module B web example")
    end
end
