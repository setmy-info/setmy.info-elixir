defmodule SetmyInfo.DemoModuleD.Application do
  @moduledoc """
  OTP application and supervision tree for `demo_module_d`.

  Supervises one Cowboy endpoint serving the app's `priv/web` demo page on
  the port configured in `config/config.exs`. Because this is the app's
  `mod:` callback, the endpoint is running for anything that starts the
  application - `iex -S mix`, `mix run --no-halt` and `mix test` alike, so
  the e2e tests need no separate server to be started around them.
  """

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Plug.Cowboy,
       scheme: :http, plug: SetmyInfo.DemoModuleD.Web, options: [port: port(), ip: {127, 0, 0, 1}]}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: SetmyInfo.DemoModuleD.Supervisor
    )
  end

  # fetch_env!, not get_env with a default: the port belongs in config/config.exs
  # and nowhere else, so a missing one is a misconfiguration, not a fallback.
  defp port, do: Application.fetch_env!(:demo_module_d, :port)
end
