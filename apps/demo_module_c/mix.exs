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
      description: "Module C - depends on a and b, proves §9.4 typed/untyped coexistence.",
      package: package(),
      start_permanent: Mix.env() == :live,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp package do
    [
      name: "setmy_info_demo_module_c",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/setmy-info/setmy.info-elixir"}
    ]
  end

  defp deps do
    [
      {:demo_module_a, in_umbrella: true},
      {:demo_module_b, in_umbrella: true},
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
