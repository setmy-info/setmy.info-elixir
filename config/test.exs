import Config

config :logger, level: :warning

# One JUnit XML per app: `mix test` recurses with each app as the current
# project, so the report directory is pinned to the umbrella root and the
# app name is prepended to keep the six files apart.
#
# The file is also named per TIER, because every `mix test` run writes the
# same file otherwise and a CI job running tier after tier would hand Jenkins
# only the last tier's results. The tier is taken from the invoked task rather
# than from an environment variable CI has to remember to set: this file is
# evaluated once, at Mix boot, before any task or alias runs (umbrella
# recursion re-applies the result, it does not re-evaluate the file), so an
# alias cannot change it afterwards - but the task name is already in argv
# here. JUNIT_REPORT_FILE still wins when set, for anything this list does not
# name.
junit_report_file =
    case System.argv() do
        ["test.unit" | _] -> "unit.xml"
        ["test.integration" | _] -> "integration.xml"
        ["test.e2e" | _] -> "e2e.xml"
        ["test.all" | _] -> "all.xml"
        ["coverage" | _] -> "coverage-run.xml"
        ["coverage.xml" | _] -> "coverage-run.xml"
        ["reports" | _] -> "coverage-run.xml"
        _ -> "test-junit-report.xml"
    end

config :junit_formatter,
    report_dir: Path.expand("../reports/junit", __DIR__),
    report_file: System.get_env("JUNIT_REPORT_FILE", junit_report_file),
    prepend_project_name?: true,
    include_filename?: true,
    automatic_create_dir?: true

# App list: keep in sync with config/config.exs (see the note there).
# `mix test` starts every app in the test VM (unit tier, `mix test <file>`,
# test.watch). Nothing there needs the endpoints, and binding the ports would
# collide with the release daemons the integration and e2e tiers talk to
# (those tiers run with --no-start anyway). The daemons themselves get
# `serve: true` for their own app from config/runtime.exs, which runs later.
for app <- [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d] do
    config app, serve: false
end
