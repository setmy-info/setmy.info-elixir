defmodule SetmyInfo.Elixir.MixProject do
  use Mix.Project

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
      releases: releases(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  # Umbrella-root deps are the shared dev/test toolchain only - the root is
  # never compiled as an app, so nothing runtime belongs here. Runtime deps
  # (including `in_umbrella:` siblings) live in each app's own mix.exs.
  #
  # sobelow is the exception that is NOT here: it refuses to run against an
  # umbrella root ("each application should be scanned separately"), so it is
  # declared per app and fanned out with `mix cmd` - see the `sobelow` alias.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs: [
        credo: :dev,
        dialyzer: :dev,
        "deps.audit": :dev,
        audit: :dev,
        quality: :dev,
        "test.unit": :test,
        "test.integration": :test,
        "test.e2e": :test,
        "test.all": :test,
        coverage: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test
      ]
    ]
  end

  # Test tiers are selected by ExUnit tags (`@moduletag :integration` /
  # `:e2e`, excluded by default in each app's test_helper.exs), not by
  # hardcoded path lists: `mix test`'s own umbrella recursion then keeps
  # working unchanged, and adding or removing an app needs no edit here.
  # The directory split under test/ is kept purely for readability.
  defp aliases do
    [
      "test.unit": ["test"],
      "test.integration": ["test --only integration"],
      "test.e2e": ["test --only e2e"],
      "test.all": ["test --include integration --include e2e"],
      # --umbrella aggregates every app's stats into one report at the root,
      # which is also the only place ExCoveralls finds coveralls.json (it reads
      # it from the current directory, and per-app runs sit in apps/<name>/).
      coverage: ["coveralls.html --umbrella --include integration --include e2e"],
      audit: ["deps.audit --ignore-file .mix_audit_ignore"],
      # `mix release` needs a name when more than one release is configured;
      # this builds them all, one after another, for the current MIX_ENV.
      "release.all": [&release_all/1],
      # Sobelow refuses to run against an umbrella root ("each application
      # should be scanned separately"), so it is fanned out over apps/* with
      # Mix's own `cmd` recursion. Flags rather than a .sobelow-conf: the
      # config file is read from the current directory, which is a different
      # app on every iteration. `--exit medium` gates on medium- and
      # high-confidence findings only: commons' whole job is reading a
      # caller-supplied config path, which Sobelow reports as a low-confidence
      # Traversal.FileModule finding. It stays printed, it just does not fail
      # the build.
      sobelow: ["cmd mix sobelow --exit medium"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "sobelow",
        "audit"
      ]
    ]
  end

  # One OTP release per deployable app, so a module is deployed on its own
  # rather than as part of one umbrella-wide artifact:
  #
  #     MIX_ENV=live mix release demo_module_a
  #     _build/live/rel/demo_module_a/bin/demo_module_a start
  #
  # `commons` has no release of its own on purpose - it is a library, consumed
  # as the Hex package `setmy_info_commons`, not run.
  @deployable_apps [:demo_module_a, :demo_module_b, :demo_module_c, :demo_module_d]

  defp releases do
    Map.new(@deployable_apps, fn app ->
      {app,
       [
         # {:from_app, app} rather than the umbrella root's own version: each
         # app is versioned independently, and the release is that app's.
         version: {:from_app, app},
         applications: [{app, :permanent}],
         include_executables_for: [:unix]
       ]}
    end)
  end

  defp release_all(args) do
    Enum.each(@deployable_apps, &Mix.Task.rerun("release", [to_string(&1) | args]))
  end

  defp dialyzer do
    [
      plt_local_path: "_build/plts",
      plt_core_path: "_build/plts",
      flags: [:error_handling]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/setmy-info/setmy.info-elixir"
    ]
  end
end
