import Config

config :logger, level: :warning

# One JUnit XML per app: `mix test` recurses with each app as the current
# project, so the report directory is pinned to the umbrella root and the
# app name is prepended to keep the five files apart.
# JUNIT_REPORT_FILE names the file per tier: every `mix test` run writes the
# same file otherwise, and CI's junit step would only see the last tier.
config :junit_formatter,
    report_dir: Path.expand("../reports/junit", __DIR__),
    report_file: System.get_env("JUNIT_REPORT_FILE", "test-junit-report.xml"),
    prepend_project_name?: true,
    include_filename?: true,
    automatic_create_dir?: true

# `mix test` starts every app in the test VM (unit tier, `mix test <file>`,
# test.watch). Nothing there needs the endpoints, and binding the ports would
# collide with the release daemons the integration and e2e tiers talk to
# (those tiers run with --no-start anyway). The daemons themselves get
# `serve: true` for their own app from config/runtime.exs, which runs later.
for app <- [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d] do
    config app, serve: false
end
