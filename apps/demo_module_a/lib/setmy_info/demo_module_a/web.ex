defmodule SetmyInfo.DemoModuleA.Web do
    @moduledoc """
    Serves `demo_module_a`'s `priv/web` directory over HTTP.

    `Plug.Static` does not map a bare `/` to `index.html` on its own, hence
    the `:index` plug in front of it; anything it does not serve falls through
    to a plain 404.
    """

    use Plug.Builder

    # Tags each request's log lines with a request_id - config/live.exs and
    # config/prelive.exs carry it in the logger metadata.
    plug(Plug.RequestId)
    plug(:index)
    plug(Plug.Static, at: "/", from: {:demo_module_a, "priv/web"})
    plug(:not_found)

    defp index(%Plug.Conn{path_info: []} = conn, _opts), do: %{conn | path_info: ["index.html"]}
    defp index(conn, _opts), do: conn

    defp not_found(conn, _opts), do: send_resp(conn, 404, "Not Found")
end
