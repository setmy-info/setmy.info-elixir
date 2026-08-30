import Config

config :logger, :console,
    format: "$date $time [$level] [$node] $metadata- $message\n",
    metadata: [:pid, :module, :function, :line]

# Each demo app's HTTP endpoint port, read by its own supervision tree
# (`SetmyInfo.DemoModule*.Application`). One config tree for the whole
# umbrella (Mix convention), namespaced per app via `config :app_name, ...`
# rather than each app carrying its own config/ directory.
config :demo_module_a, port: 48101
config :demo_module_b, port: 48111
config :demo_module_c, port: 48121
config :demo_module_d, port: 48131

# ExCoveralls reads coveralls.json from the current working directory, which
# during umbrella recursion is each app's own directory. Point it at the single
# file at the umbrella root instead of keeping five copies in sync.
config :excoveralls, config_file: Path.expand("../coveralls.json", __DIR__)

import_config "#{config_env()}.exs"
