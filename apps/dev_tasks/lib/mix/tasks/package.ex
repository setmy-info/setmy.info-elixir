defmodule Mix.Tasks.Package do
  use Mix.Task

  @shortdoc "Package phase (§2 row 16): produces the distributable .tar via mix hex.build"

  @moduledoc """
  `mix hex.build` per app - the Elixir/Hex analogue of a wheel/npm-pack
  tarball. Output moved to `.artifacts/<dist-name>/`, same convention as the
  JS/Python sides.

  Apps with `in_umbrella: true` local dependencies (demo_module_c,
  demo_module_d) are skipped, not force-packaged: Hex refuses to build a
  package whose deps aren't real Hex packages ("Dependencies excluded from
  the package: only Hex packages can be dependencies") - hit this for real
  running `mix hex.build` against demo_module_c before adding this skip, not
  assumed in advance. This is a genuine structural tension between §13.1
  (every module independently publishable) and Elixir umbrella apps
  depending on each other via in-repo links - not a bug this task can paper
  over. See report.md for the full writeup.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), &package_app/1)
  end

  defp package_app(app) do
    if app.local_deps == [] do
      build_package(app)
    else
      Mix.shell().info(
        "Skipping package for #{app.name}: depends on in-umbrella app(s) " <>
          "#{inspect(app.local_deps)}, which Hex refuses to package as real dependencies " <>
          "(see the Package task's @moduledoc)."
      )
    end
  end

  defp build_package(app) do
    dist_name = "setmy_info_#{app.name}"
    artifacts_dir = Path.join([WorkspaceHelper.root_dir(), ".artifacts", dist_name])
    File.mkdir_p!(artifacts_dir)

    mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")
    {output, exit_code} = System.cmd(mix_bin, ["hex.build"], cd: app.path, stderr_to_stdout: true)
    Mix.shell().info(output)

    if exit_code != 0 do
      Mix.raise("mix hex.build failed for #{app.name} with exit code #{exit_code}")
    end

    [tar_path] = Path.wildcard(Path.join(app.path, "*.tar"))
    dest_path = Path.join(artifacts_dir, Path.basename(tar_path))
    File.rename!(tar_path, dest_path)

    Mix.shell().info("Packaged #{app.name} into #{dest_path}")
  end
end
