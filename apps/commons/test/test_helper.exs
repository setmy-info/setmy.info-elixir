# Shared ExUnit.CaseTemplate for the tiers that are allowed to touch the
# environment. A `.exs` required from here rather than compiled as test-only
# code: the compiled app and the Hex package never depend on it (formatter/
# is this app's one extra elixirc path, and that is a build tool, not test
# support).
Code.require_file("support/environment_case.exs", __DIR__)

# Test tiers are tags, not paths: a bare `mix test` runs the unit tier only,
# and `mix test.integration` / `mix test.e2e` / `mix test.all` opt the slower
# tiers back in.
# JUnit XML beside the console output, one file per app under reports/junit/
# (config/test.exs) - what Jenkins' junit step reads.
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

ExUnit.start(exclude: [:integration, :e2e])
