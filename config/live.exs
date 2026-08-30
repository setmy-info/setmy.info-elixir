import Config

config :logger,
    level: :info,
    utc_log: true

config :logger, :console,
    format: "$date $timeZ [$level] [$node] $metadata- $message\n",
    metadata: [:pid, :module, :request_id]
