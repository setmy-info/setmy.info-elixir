defmodule Commons.MixProject do
    use Mix.Project

    def project do
        [
            app: :commons,
            version: "1.0.0",
            build_path: "../../_build",
            config_path: "../../config/config.exs",
            deps_path: "../../deps",
            lockfile: "../../mix.lock",
            elixir: "~> 1.19",
            description:
                "Spring Boot style layered application configuration - YAML files, profiled YAML " <>
                    "overlays, environment placeholder resolution, environment variable overrides and " <>
                    "CLI option overrides. Elixir row of clj-commons / python-commons.",
            package: package(),
            start_permanent: Mix.env() == :live,
            # Declared per app, not only at the umbrella root: `mix test --cover`
            # runs with each app as the current project, and without this it falls
            # back to Mix's built-in cover tool instead of ExCoveralls.
            test_coverage: [tool: ExCoveralls],
            # test/support/ holds the shared ExUnit.CaseTemplate, required from
            # test_helper.exs rather than loaded as a test file.
            test_ignore_filters: [~r"^test/support/"],
            # formatter/ holds the umbrella's `mix format` plugin - compiled with
            # the app so `mix format` finds it, kept out of package files: below.
            elixirc_paths: ["lib", "formatter"],
            deps: deps()
        ]
    end

    # Explicit file allowlist rather than Hex's default set: this app carries
    # test/resources/*.yaml fixtures that must never ship to consumers.
    defp package do
        [
            name: "setmy_info_commons",
            licenses: ["MIT"],
            links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"},
            files: ["lib", "mix.exs", ".formatter.exs"]
        ]
    end

    # yaml_elixir is a real runtime dependency: parsing application.yaml is this
    # library's whole job. sobelow is declared per app for the reason every other
    # app declares it - see demo_module_a's mix.exs comment.
    defp deps do
        [
            {:yaml_elixir, "~> 2.12"},
            {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
            {:sbom, "~> 0.10", only: [:dev, :test], runtime: false},
            {:excoveralls, "~> 0.18", only: :test, runtime: false}
        ]
    end

    def application do
        [
            extra_applications: [:logger]
        ]
    end
end
