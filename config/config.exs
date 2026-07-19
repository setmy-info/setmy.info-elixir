import Config

config :logger, :console,
  format: "$date $time [$level] [$node] $metadata- $message\n",
  metadata: [:pid, :module, :function, :line]

# Per-app e2e/dev server port + static web dir - the umbrella equivalent of
# the JS side's package.json `config.server` / Python's pyproject.toml
# `[tool.server]`. One config tree for the whole umbrella (Mix convention),
# namespaced per app via `config :app_name, ...` rather than each app having
# its own config/ directory.
config :demo_module_a, port: 48101, web_dir: "priv/web"
config :demo_module_b, port: 48111, web_dir: "priv/web"
config :demo_module_c, port: 48121, web_dir: "priv/web"
config :demo_module_d, port: 48131, web_dir: "priv/web"

import_config "#{config_env()}.exs"
