# The e2e server test makes a real HTTP request with :httpc, which needs
# :inets running; it is not started by default.
{:ok, _} = Application.ensure_all_started(:inets)

# Test tiers are tags, not paths: a bare `mix test` runs the unit tier only,
# and `mix test.integration` / `mix test.e2e` / `mix test.all` opt the slower
# tiers back in.
# JUnit XML beside the console output, one file per app under reports/junit/
# (config/test.exs) - what Jenkins' junit step reads.
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

ExUnit.start(exclude: [:integration, :e2e])
