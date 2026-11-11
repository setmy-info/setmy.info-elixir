import Config

config :logger,
    level: :info,
    utc_log: true

config :logger, :console,
    format: "$date $timeZ [$level] [$node] $metadata- $message\n",
    metadata: [:pid, :module, :request_id]

# Installed (rpm/), the apps are not a release and this file, through
# config.exs, becomes their sys.config: no app serves unless the script that
# starts it says so (`-<app> serve true`, src/main/sh/bin/smi-elixir-start).
# A release of one app still serves it (config/runtime.exs).
# App list: keep in sync with config/config.exs (see the note there).
for app <- [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d] do
    config app, serve: false
end
