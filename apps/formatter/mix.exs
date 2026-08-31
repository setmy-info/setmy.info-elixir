defmodule Formatter.MixProject do
    use Mix.Project

    def project do
        [
            app: :formatter,
            version: "1.0.0",
            build_path: "../../_build",
            config_path: "../../config/config.exs",
            deps_path: "../../deps",
            lockfile: "../../mix.lock",
            elixir: "~> 1.19",
            description:
                "4-space indentation plugin for `mix format`: runs the stock formatter and widens " <>
                    "each nesting level from 2 to 4 spaces, leaving alignment and string values untouched.",
            package: package(),
            start_permanent: Mix.env() == :live,
            # Declared per app, not only at the umbrella root: `mix test --cover`
            # runs with each app as the current project, and without this it falls
            # back to Mix's built-in cover tool instead of ExCoveralls.
            test_coverage: [tool: ExCoveralls],
            deps: deps()
        ]
    end

    # A build tool, not an OTP application: no supervision tree, and no
    # `:mix` in extra_applications - the module is only ever called from
    # inside a running Mix (`mix format`), never from a release.
    def application do
        [extra_applications: []]
    end

    # Explicit file allowlist rather than Hex's default set, matching every
    # other app in this umbrella.
    defp package do
        [
            name: "setmy_info_formatter",
            licenses: ["MIT"],
            links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"},
            files: ["lib", "mix.exs", ".formatter.exs"]
        ]
    end

    # sobelow and sbom are declared per app rather than at the umbrella root:
    # sobelow refuses to run against an umbrella root ("each application should
    # be scanned separately") and an SBOM is per artifact, so both always run
    # with a single app as the current project - and a task's binary only
    # resolves against that project's own deps.
    defp deps do
        [
            {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
            {:sbom, "~> 0.10", only: [:dev, :test], runtime: false},
            {:excoveralls, "~> 0.18", only: :test, runtime: false},
            # Also declared here, not only at the umbrella root: each app's
            # test_helper.exs names JUnitFormatter unconditionally, and a root-only
            # dependency is not on the code path when this app is the current
            # project (`cd apps/<name> && mix test`).
            {:junit_formatter, "~> 3.4", only: :test, runtime: false}
        ]
    end
end
