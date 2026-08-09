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
      elixir: "~> 1.18",
      description:
        "Spring Boot style layered application configuration - YAML files, profiled YAML " <>
          "overlays, environment placeholder resolution, environment variable overrides and " <>
          "CLI option overrides. Elixir row of clj-commons / python-commons.",
      package: package(),
      start_permanent: Mix.env() == :live,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Same explicit allowlist reasoning as demo_module_a's own package/0: Hex's
  # default file set sweeps in all of priv/, and this app additionally carries
  # test/resources/*.yaml fixtures that must never ship to consumers.
  defp package do
    [
      name: "setmy_info_commons",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"},
      files: ["lib", "mix.exs", ".formatter.exs"]
    ]
  end

  # yaml_elixir is a real runtime dependency here (not dev tooling like it is
  # for dev_tasks): parsing application.yaml is this library's whole job.
  # sobelow per-app for the same reason every other app declares it - see
  # demo_module_a's mix.exs comment.
  defp deps do
    [
      {:yaml_elixir, "~> 2.12"},
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
