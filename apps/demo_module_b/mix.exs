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
      elixir: "~> 1.18",
      description:
        "Module B - the typed worked example (§9): full @spec coverage, Dialyzer-checked.",
      package: package(),
      start_permanent: Mix.env() == :live,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      # Presence of this key, and only its presence, is what opts this app
      # into the typed/Dialyzer-checked mode (mirrors the JS side's
      # src/index.ts-presence check for TypeScript, Python's [tool.mypy]
      # table presence).
      dialyzer: [
        plt_add_apps: [:demo_module_b],
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  defp package do
    [
      name: "setmy_info_demo_module_b",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"},
      # Explicit allowlist - same reasoning as demo_module_a's package/0:
      # keep mix-resources' generated priv/resources/<profile>/ output out
      # of the published package (§6.6).
      files: ["lib", "priv/web", "mix.exs", ".formatter.exs"]
    ]
  end

  # dialyxir declared here, not (only) at the umbrella root: `mix dialyzer`
  # run with this app as the current project (Mix.Tasks.Validate shells out
  # with `cd: app.path`) only sees tasks from deps *this* mix.exs declares -
  # confirmed by hitting "The task \"dialyzer\" could not be found" with only
  # the root-level declaration, not assumed. Also the more correct place for
  # it anyway: dialyzer is meant to be opt-in per app, so the dependency
  # itself should only be pulled for apps that use it. `only:
  # [:dev, :test]` keeps it out of what Hex actually publishes.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
