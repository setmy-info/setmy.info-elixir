defmodule SetmyInfo.DemoModuleC.ServerTest do
  use ExUnit.Case, async: true

  test "e2e server serves the web page" do
    {:ok, {{_, 200, _}, _headers, body}} =
      :httpc.request(~c"http://127.0.0.1:48121/")

    assert String.contains?(to_string(body), "Module C web example")
  end
end
