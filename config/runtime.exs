import Config

log_level =
  case System.get_env("SETMY_INFO_LOG_LEVEL", "info") |> String.downcase() do
    "debug" -> :debug
    "info" -> :info
    "warning" -> :warning
    "error" -> :error
    _ -> :info
  end

if config_env() in [:live, :prelive] do
  config :logger, level: log_level
end
