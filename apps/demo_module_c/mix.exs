defmodule DemoModuleC.MixProject do
    use Mix.Project

    def project do
        [
            app: :demo_module_c,
            version: "1.0.0",
            build_path: "../../_build",
            config_path: "../../config/config.exs",
            deps_path: "../../deps",
            lockfile: "../../mix.lock",
            elixir: "~> 1.19",
            description: "Module C - depends on a and b, proving typed/untyped coexistence.",
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
            mod: {SetmyInfo.DemoModuleC.Application, []}
        ]
    end

    # Explicit file allowlist rather than Hex's default set, which sweeps in
    # all of priv/.
    defp package do
        [
            name: "setmy_info_demo_module_c",
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
            sibling(:demo_module_a, :setmy_info_demo_module_a),
            sibling(:demo_module_b, :setmy_info_demo_module_b),
            {:plug_cowboy, "~> 2.7"},
            {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
            {:sbom, "~> 0.10", only: [:dev, :test], runtime: false},
            {:excoveralls, "~> 0.18", only: :test, runtime: false}
        ]
    end

    # Umbrella siblings are declared twice over, on purpose.
    #
    # `in_umbrella: true` is what makes local development work: the sibling is
    # compiled from `apps/`, no publishing round-trip in the loop.
    #
    # Hex, though, refuses to package a dependency that carries any SCM key
    # (`:git`, `:github`, `:path`, `:in_umbrella`) unless it also carries `:hex`
    # - without it, `mix hex.build` stops with "Dependencies excluded from the
    # package (only Hex packages can be dependencies)". And `:hex` cannot simply
    # be left on permanently: it makes Hex resolve the sibling's OWN dependencies
    # from the registry instead of from its mix.exs, so `mix compile` run from
    # inside this directory then fails to compile the sibling ("Plug.Conn is not
    # available" - reproduced, not assumed).
    #
    # So `:hex` is added only when HEX_BUILD is set, which is exactly when a
    # package is being built:
    #
    #     HEX_BUILD=1 mix hex.publish package
    defp sibling(app, hex_package) do
        cond do
            System.get_env("HEX_BUILD") not in [nil, ""] ->
                {app, "~> 1.0", in_umbrella: true, hex: hex_package}

            # Packaging without it would fail several screens later, in Hex's
            # own words ("Dependencies excluded from the package"), naming the
            # siblings but not the reason. Say it here instead.
            packaging?() ->
                Mix.raise(
                    "demo_module_c depends on umbrella siblings, so packaging it needs " <>
                        "HEX_BUILD=1 (see \"Why HEX_BUILD\" in the umbrella README):\n\n" <>
                        "    HEX_BUILD=1 mix #{Enum.join(System.argv(), " ")}\n"
                )

            true ->
                {app, "~> 1.0", in_umbrella: true}
        end
    end

    # `mix hex.build` / `mix hex.publish`, run in this app's directory or by
    # `mix cmd` from the umbrella root - not `hex.audit` and friends, which
    # never look at the package's dependency list.
    defp packaging? do
        case System.argv() do
            [task | _] -> task in ["hex.build", "hex.publish"]
            _ -> false
        end
    end
end
