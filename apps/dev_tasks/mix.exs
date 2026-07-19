defmodule DevTasks.MixProject do
  use Mix.Project

  def project do
    [
      app: :dev_tasks,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Custom Mix.Task modules only become globally invokable from the umbrella
  # root once compiled as part of a real app - verified directly (a task
  # placed straight under the umbrella root's own lib/mix/tasks/ was NOT
  # found by `mix <task>` even after `mix compile`, exactly the way a
  # regular dep's custom tasks - credo, sobelow, ex_doc - only become
  # available once that dep is compiled). This app exists purely to host
  # them, playing the same role those deps play for their own tasks - the
  # Elixir-native equivalent of the JS side's tools/*.js / Python's
  # scripts/*.py orchestration layer.
  defp deps do
    [
      {:yaml_elixir, "~> 2.12"},
      {:plug_cowboy, "~> 2.7"}
    ]
  end

  defp elixirc_paths(_), do: ["lib"]
end
