defmodule SetmyInfo.DemoModuleD.Application do
    @moduledoc """
    OTP application and supervision tree for `demo_module_d`.

    Supervises one Cowboy endpoint serving the app's `priv/web` demo page on
    the port configured in `config/config.exs`. Because this is the app's
    `mod:` callback, the endpoint is running for anything that starts the
    application - `iex -S mix` and `mix run --no-halt` alike. The integration
    and e2e tiers run with `--no-start` against this app's own OTP release,
    started by the tiers' pre step (`mix server.start`, see the umbrella's
    lifecycle.exs); see `config/runtime.exs` for why only the release's own app
    serves there.
    """

    use Application

    @impl Application
    def start(_type, _args) do
        children =
            if serve?() do
                [
                    {Plug.Cowboy,
                      scheme: :http,
                      plug: SetmyInfo.DemoModuleD.Web,
                      options: [port: port(), ip: {127, 0, 0, 1}]}
                ]
            else
                []
            end

        Supervisor.start_link(children,
            strategy: :one_for_one,
            name: SetmyInfo.DemoModuleD.Supervisor
        )
    end

    # fetch_env!, not get_env with a default: the port belongs in config/config.exs
    # and nowhere else, so a missing one is a misconfiguration, not a fallback.
    defp port, do: Application.fetch_env!(:demo_module_d, :port)

    # Off only when this app is embedded in another app's OTP release as a
    # library - see config/runtime.exs. Default true: under Mix every app serves.
    defp serve?, do: Application.get_env(:demo_module_d, :serve, true)
end
