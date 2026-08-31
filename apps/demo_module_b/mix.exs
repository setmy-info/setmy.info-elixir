defmodule DemoModuleB.MixProject do
    use Mix.Project

    def project do
        [
            app: :demo_module_b,
            version: "1.0.0",
            build_path: "../../_build",
            config_path: "../../config/config.exs",
            deps_path: "../../deps",
            lockfile: "../../mix.lock",
            elixir: "~> 1.19",
            description: "Module B - the typed worked example: full @spec coverage, Dialyzer-checked.",
            package: package(),
            start_permanent: Mix.env() == :live,
            # Declared per app, not only at the umbrella root: `mix test --cover`
            # runs with each app as the current project, and without this it falls
            # back to Mix's built-in cover tool instead of ExCoveralls.
            test_coverage: [tool: ExCoveralls],
            deps: deps()
        ]
    end

    def application do
        [
            extra_applications: [:logger],
            mod: {SetmyInfo.DemoModuleB.Application, []}
        ]
    end

    # Explicit file allowlist rather than Hex's default set, which sweeps in
    # all of priv/.
    defp package do
        [
            name: "setmy_info_demo_module_b",
            licenses: ["MIT"],
            links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"},
            files: ["lib", "priv/web", "mix.exs", ".formatter.exs"]
        ]
    end

    # sobelow and sbom are declared per app rather than at the umbrella root:
    # sobelow refuses to run against an umbrella root ("each application should
    # be scanned separately") and an SBOM is per artifact, so both always run
    # with a single app as the current project - and a task's binary only
    # resolves against that project's own deps.
    defp deps do
        [
            {:plug_cowboy, "~> 2.7"},
            {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
            {:sbom, "~> 0.10", only: [:dev, :test], runtime: false},
            {:excoveralls, "~> 0.18", only: :test, runtime: false}
        ]
    end
end
