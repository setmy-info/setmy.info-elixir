defmodule SetmyInfo.Elixir.MixProject do
  use Mix.Project

  @coveralls_commands [
    :coveralls,
    :"coveralls.detail",
    :"coveralls.html",
    :"coveralls.json",
    :"coveralls.post"
  ]

  def project do
    [
      apps_path: "apps",
      name: "setmy.info-elixir",
      version: "0.1.0",
      start_permanent: Mix.env() == :live,
      deps: deps(),
      aliases: aliases(),
      cli: cli(),
      test_coverage: [tool: ExCoveralls],
      docs: [
        main: "readme",
        extras: ["README.md"],
        output: "docs",
        source_url: "https://github.com/setmy-info/setmy.info-elixir"
      ]
    ]
  end

  # Shared dev/test tooling for every app in the umbrella - real precedent:
  # elixir-start-project/PoC/first's own root mix.exs declares ex_doc here the
  # same way, even though the umbrella root itself is never "compiled" as an
  # app. Per-app runtime deps (including in_umbrella siblings) live in each
  # app's own mix.exs instead. dialyxir and sobelow are NOT here - both are
  # declared per-app instead (demo_module_b for dialyxir; all four demo apps
  # for sobelow): a root-only declaration doesn't make either task's binary
  # visible when that task runs with a specific app as the current project
  # (see demo_module_a's mix.exs comment for sobelow, demo_module_b's for
  # dialyxir), and Sobelow additionally just refuses to run at an umbrella
  # root at all ("each application should be scanned separately" - hit this
  # directly, not assumed).
  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:yaml_elixir, "~> 2.12"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs:
        [
          {:credo, :dev},
          {:"deps.audit", :dev},
          {:"test.unit", :test},
          {:"test.integration", :test},
          {:"test.e2e", :test},
          {:tooling_test, :test},
          {:coverage, :test}
        ] ++ Enum.map(@coveralls_commands, &{&1, :test})
    ]
  end

  # Directory-based test tiers (§7.1), as plain aliases composing existing
  # `mix test` invocations with explicit paths - real precedent:
  # elixir-start-project/PoC/first's own root mix.exs does exactly this
  # (`"test.unit": ["test #{Enum.join(@unit_test_paths, " ")}"]`), and it's
  # the only approach that actually works for tasks named "test.*" at an
  # umbrella root: a custom `Mix.Tasks.Test.Unit` module in the dev_tasks
  # app was tried first and never found - `mix test.unit`/`.integration`/
  # `.e2e` collide with Mix's *built-in* `test` task's alias-resolution
  # umbrella recursion in a way plain `Mix.Task` modules under a compiled
  # app don't reliably intercept, unlike every other custom task here
  # (resources, server, deploy, ...), which aren't named after a built-in.
  # NOT a "validate" alias here: that used to compose `compile
  # --warnings-as-errors` + `format --check-formatted` under one name, but
  # those are two separate §2 phases (rows 4 and 7), not part of Validate
  # (row 3, structural + type-check) - conflating them under one alias also
  # silently shadowed the real `Mix.Tasks.Validate` module in dev_tasks
  # (Mix resolves aliases before task modules of the same name), caught by
  # `mix validate` visibly running `format --check-formatted` instead of
  # Dialyzer, not assumed in advance.
  defp aliases do
    [
      "test.unit": [
        "test apps/demo_module_a/test/unit apps/demo_module_b/test/unit " <>
          "apps/demo_module_c/test/unit apps/demo_module_d/test/unit"
      ],
      "test.integration": [
        "test apps/demo_module_a/test/integration apps/demo_module_b/test/integration " <>
          "apps/demo_module_c/test/integration apps/demo_module_d/test/integration"
      ],
      "test.e2e": [
        "test apps/demo_module_a/test/e2e apps/demo_module_b/test/e2e " <>
          "apps/demo_module_c/test/e2e apps/demo_module_d/test/e2e"
      ],
      # Build tooling's own tests (§7.7) - dev_tasks' test/unit (pure) and
      # test/integration (real subprocess + real server + real request).
      tooling_test: ["test apps/dev_tasks/test/unit apps/dev_tasks/test/integration"],
      # Coverage (§2 row 13) scoped to unit tests only, same paths as
      # test.unit - a bare `mix coveralls` picks up *every* test tier
      # including e2e, which then fails with connection-refused unless the
      # e2e servers happen to already be running (hit this for real, not
      # assumed): unit coverage is what this phase is supposed to measure,
      # same scope the JS/Python sides' own coverage phase uses.
      coverage: [
        "coveralls apps/demo_module_a/test/unit apps/demo_module_b/test/unit " <>
          "apps/demo_module_c/test/unit apps/demo_module_d/test/unit"
      ]
    ]
  end
end
