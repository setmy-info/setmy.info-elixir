defmodule Mix.Tasks.Validate do
  use Mix.Task

  @shortdoc "Validate phase (§2 row 3): structural checks + Dialyzer for the typed app"

  @moduledoc """
  Structural sanity + type-check for a module that opted into the typed
  mode (§9.2). Mirrors `tools/validate.js` / `scripts/validate.py`: same
  "only type-check if the module opted in" rule - a module opts in purely
  by having a `:dialyzer` key in its own `mix.exs`, exactly mirroring the
  JS side's tsconfig.json-presence check / Python's [tool.mypy]-presence
  check.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), &validate_app/1)
  end

  defp validate_app(app) do
    mix_exs_path = Path.join(app.path, "mix.exs")

    unless File.exists?(mix_exs_path) do
      Mix.raise("Missing mix.exs for #{app.name}")
    end

    config = Mix.Project.in_project(app.name, app.path, fn _module -> Mix.Project.config() end)

    unless config[:version] do
      Mix.raise("mix.exs for #{app.name} is missing :version")
    end

    if Keyword.has_key?(config, :dialyzer) do
      Mix.shell().info("Running Dialyzer for #{app.name} (opted in via :dialyzer key)")
      run_dialyzer!(app)
    end

    Mix.shell().info("Validated #{app.name}")
  end

  defp run_dialyzer!(app) do
    mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")
    {output, exit_code} = System.cmd(mix_bin, ["dialyzer"], cd: app.path, stderr_to_stdout: true)
    Mix.shell().info(output)

    if exit_code != 0 do
      Mix.raise("Dialyzer failed for #{app.name} (see output above)")
    end
  end
end
