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

# Inside an OTP release only the release's OWN app serves HTTP. demo_module_c's
# release, say, also starts demo_module_a and demo_module_b (it depends on
# them, and Mix will not let a :permanent app's deps be merely loaded), but
# there they are libraries, and a second copy of demo_module_a's endpoint next
# to demo_module_a's own release fails with :eaddrinuse. Under Mix (`iex -S
# mix`, `mix test`) RELEASE_NAME is unset and every app serves, as before.
if release = System.get_env("RELEASE_NAME") do
    for app <- [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d] do
        config app, serve: Atom.to_string(app) == release
    end
end
