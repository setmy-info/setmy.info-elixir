defmodule DemoModuleA.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo_module_a,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      description: "Module A - base module, no local dependencies.",
      package: package(),
      start_permanent: Mix.env() == :live,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp package do
    [
      name: "setmy_info_demo_module_a",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"}
    ]
  end

  # sobelow declared per-app, not (only) at the umbrella root: `mix sobelow`
  # run with this app as the current project needs the dep declared here to
  # find the task - same "task tools resolve against the current project's
  # own deps()" constraint that demo_module_b's dialyxir dep already
  # documents. Also: Sobelow itself refuses to run at an umbrella root
  # ("each application should be scanned separately" - confirmed by running
  # it there first, not assumed), so per-app is the only way this works at
  # all, not just the more-correct one.
  defp deps do
    [
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
