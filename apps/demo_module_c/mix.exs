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
      elixir: "~> 1.18",
      description: "Module C - depends on a and b, proving typed/untyped coexistence.",
      package: package(),
      start_permanent: Mix.env() == :live,
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # sobelow is declared per app rather than at the umbrella root: it refuses
  # to run against an umbrella root ("each application should be scanned
  # separately"), so `mix sobelow` is always run with a single app as the
  # current project, and a task's binary only resolves against that
  # project's own deps.
  defp deps do
    [
      sibling(:demo_module_a, :setmy_info_demo_module_a),
      sibling(:demo_module_b, :setmy_info_demo_module_b),
      {:plug_cowboy, "~> 2.7"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
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
  #     HEX_BUILD=1 mix hex.publish
  defp sibling(app, hex_package) do
    if System.get_env("HEX_BUILD") in [nil, ""] do
      {app, "~> 1.0", in_umbrella: true}
    else
      {app, "~> 1.0", in_umbrella: true, hex: hex_package}
    end
  end

  defp elixirc_paths(_), do: ["lib"]
end
