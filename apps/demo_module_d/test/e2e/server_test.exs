defmodule SetmyInfo.DemoModuleD.ServerTest do
  @moduledoc """
  Real HTTP requests against the app's own running instance - the Cowboy
  endpoint supervised by `SetmyInfo.DemoModuleD.Application`, which `mix test`
  brings up together with the application itself.
  """

  use ExUnit.Case, async: true

  @moduletag :e2e

  @base ~c"http://127.0.0.1:48131"

  test "serves the demo page at the root" do
    {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(@base ++ ~c"/")

    assert String.contains?(to_string(body), "Module D web example")
  end

  test "serves the demo page at its own path" do
    {:ok, {{_, 200, _}, _headers, body}} = :httpc.request(@base ++ ~c"/index.html")

    assert String.contains?(to_string(body), "Module D web example")
  end

  test "answers 404 for anything else" do
    {:ok, {{_, 404, _}, _headers, _body}} = :httpc.request(@base ++ ~c"/no-such-page")
  end
end
