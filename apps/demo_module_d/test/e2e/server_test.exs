defmodule SetmyInfo.DemoModuleD.ServerTest do
    @moduledoc """
    Real HTTP requests against the app's own running instance: the OTP release
    daemon started by the tier's pre step (`mix server.start`, see the
    umbrella's lifecycle.exs; this tier runs with `--no-start`, so nothing
    listens inside the test VM itself). Requires `mix test.e2e`, or an explicit
    `mix pre-e2e-test` first.
    """

    use ExUnit.Case, async: true

    @moduletag :e2e

    # The port comes from config/config.exs, the same place the daemon read it.
    defp base, do: ~c"http://127.0.0.1:#{Application.fetch_env!(:demo_module_d, :port)}"

    test "serves the demo page at the root" do
        {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(base() ++ ~c"/")

        assert String.contains?(to_string(body), "Module D web example")
    end

    test "serves the demo page at its own path" do
        {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(base() ++ ~c"/index.html")

        assert String.contains?(to_string(body), "Module D web example")
    end

    test "answers 404 for anything else" do
        {:ok, {{_, 404, _}, _headers, _body}} = :httpc.request(base() ++ ~c"/no-such-page")
    end
end
