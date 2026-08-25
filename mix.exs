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
      # Clean (§2 row 2, "MUST be safe to run from a dirty state"): Maven's
      # `clean` removes target/ - *everything* generated - whereas stock
      # `mix clean` only removes _build/ compile output. The lifecycle tasks
      # here also generate .artifacts/ (tarballs, http-server state files),
      # .deploy/, .signatures/, docs/ (Site's ExDoc output) and
      # apps/*/priv/resources/ (Resources' profile-filtered output), and
      # register background servers whose state file alone wedges a later
      # `mix pre_integration_test` with "already registered". Ported from
      # setmy.info-js/report.md Round 10 item 46 (see report.md Round 3).
      clean: ["clean", &clean_generated/1],
      "test.unit": [
        "test apps/commons/test/unit " <>
          "apps/demo_module_a/test/unit apps/demo_module_b/test/unit " <>
          "apps/demo_module_c/test/unit apps/demo_module_d/test/unit"
      ],
      "test.integration": [
        "test apps/commons/test/integration " <>
          "apps/demo_module_a/test/integration apps/demo_module_b/test/integration " <>
          "apps/demo_module_c/test/integration apps/demo_module_d/test/integration"
      ],
      "test.e2e": [
        "test apps/commons/test/e2e " <>
          "apps/demo_module_a/test/e2e apps/demo_module_b/test/e2e " <>
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
      # commons also contributes its integration and e2e tiers here, unlike
      # the demo apps. ADR-0031 forbids unit tests from touching config
      # files, data files or environment variables - and reading exactly
      # those is what setmy_info_commons *is*, so unit-only coverage
      # measures the wrong thing for it (52% against a fully tested
      # library, measured). Safe to include because commons' own
      # integration/e2e tiers need no running instance: the demo apps' e2e
      # tier does, which is why theirs stays out (see the comment on
      # test.e2e and Mix.Tasks.PreE2eTest).
      coverage: [
        "coveralls apps/commons/test/unit apps/commons/test/integration apps/commons/test/e2e " <>
          "apps/demo_module_a/test/unit apps/demo_module_b/test/unit " <>
          "apps/demo_module_c/test/unit apps/demo_module_d/test/unit"
      ]
    ]
  end

  @generated_dirs [".artifacts", ".deploy", ".signatures", "docs"]

  # Stops every HTTP server registered in .artifacts/http-servers/*.json
  # (dead pids ignored), then removes every generated directory. A plain
  # function rather than a Mix.Tasks.Clean module in dev_tasks: `clean` is a
  # built-in task name, and (as the test.* comment above records) custom
  # task modules named after built-ins don't reliably win at an umbrella
  # root - and the whole point of clean is to work when _build/ (where
  # dev_tasks' compiled tasks live) is already gone.
  defp clean_generated(_args) do
    File.cwd!()
    |> Path.join(".artifacts/http-servers/*.json")
    |> Path.wildcard()
    |> Enum.each(&stop_registered_server/1)

    # apps/*/*.tar: `mix hex.build` run in place (Publish's dry-run path)
    # leaves the tarball in the app dir - generated, git-ignored (`**.tar`).
    generated =
      Enum.map(@generated_dirs, &Path.join(File.cwd!(), &1)) ++
        Path.wildcard(Path.join(File.cwd!(), "apps/*/priv/resources")) ++
        Path.wildcard(Path.join(File.cwd!(), "apps/*/*.tar"))

    Enum.each(generated, fn dir ->
      if File.exists?(dir) do
        File.rm_rf!(dir)
        Mix.shell().info("Removed #{Path.relative_to_cwd(dir)}")
      end
    end)
  end

  defp stop_registered_server(state_file) do
    case Regex.run(~r/"pid"\s*:\s*"?(\d+)"?/, File.read!(state_file)) do
      [_, pid] ->
        # `kill` exits non-zero when the pid is already dead - that's the
        # dirty-state case this exists for, so it is deliberately ignored.
        {_output, _status} = System.cmd("kill", [pid], stderr_to_stdout: true)
        Mix.shell().info("Stopped HTTP server pid #{pid} (#{Path.relative_to_cwd(state_file)})")

      _ ->
        Mix.shell().info("Ignoring unreadable server state file #{state_file}")
    end
  end
end
