import Config

# Genuinely new: neither PoC/second nor elixir-module-loader has a prelive.exs
# yet (elixir-module-loader has local/dev/ci/test/live - 5 of ADR-0041's 6).
# Mirrors live.exs closely on purpose - prelive exists to validate
# production-like behavior before live, not to diverge from it.
config :logger,
    level: :info,
    utc_log: true

config :logger, :console,
    format: "$date $timeZ [$level] [$node] $metadata- $message\n",
  metadata: [:pid, :module, :request_id]
