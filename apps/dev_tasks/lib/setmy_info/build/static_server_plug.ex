defmodule SetmyInfo.Build.StaticServerPlug do
  @moduledoc """
  Static file server used by `mix server serve`. Mirrors
  `tools/http-server.js` / `scripts/http_server.py`'s "serve" mode -
  delegates the actual file serving (and path-traversal safety) to
  `Plug.Static`, the same way the Python side delegates to stdlib
  `http.server.SimpleHTTPRequestHandler` rather than hand-rolling it.
  """

  @behaviour Plug

  @impl Plug
  def init(opts) do
    dir = Keyword.fetch!(opts, :dir)
    Plug.Static.init(at: "/", from: dir)
  end

  @impl Plug
  def call(conn, static_opts) do
    # Plug.Static does not rewrite a bare "/" to "/index.html" itself -
    # confirmed by hitting a real 404 on "/" before adding this, not assumed.
    conn = if conn.path_info == [], do: %{conn | path_info: ["index.html"]}, else: conn
    conn = Plug.Static.call(conn, static_opts)

    if conn.halted do
      conn
    else
      Plug.Conn.send_resp(conn, 404, "Not Found")
    end
  end
end
