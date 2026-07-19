defmodule Mix.Tasks.Security do
  use Mix.Task

  @shortdoc "Security phase (§2 row 14): Sobelow per app + mix deps.audit at root"

  @moduledoc """
  Sobelow (static security analysis, per demo app - it refuses to run at an
  umbrella root, see Site's @moduledoc) plus `mix deps.audit` (dependency
  vulnerability audit, root-level - one shared `mix.lock` for the whole
  umbrella, same reasoning as SBOM). Gates the build, unlike Site's own
  report copy of the same Sobelow output.

  `--ignore-file .mix_audit_ignore` passed to deps.audit: two real,
  currently-unfixable-by-version-bump cowlib advisories are documented and
  ignored there (see that file for the full reasoning per finding) - not a
  blanket suppression, requirements-rules.md §12.3's "stay visible, don't
  hide" rule applied to a dependency-audit finding instead of a static-
  analysis one.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")

    Enum.each(WorkspaceHelper.demo_apps_in_order(), &run_sobelow(&1, mix_bin))
    run_deps_audit(mix_bin)
  end

  defp run_sobelow(app, mix_bin) do
    {output, exit_code} =
      System.cmd(mix_bin, ["sobelow", "--config"], cd: app.path, stderr_to_stdout: true)

    Mix.shell().info(output)

    if exit_code != 0 do
      Mix.raise("Sobelow found findings for #{app.name} (see output above)")
    end
  end

  defp run_deps_audit(mix_bin) do
    root = WorkspaceHelper.root_dir()
    ignore_file = Path.join(root, ".mix_audit_ignore")

    {output, exit_code} =
      System.cmd(mix_bin, ["deps.audit", "--ignore-file", ignore_file],
        cd: root,
        stderr_to_stdout: true
      )

    Mix.shell().info(output)

    if exit_code != 0 do
      Mix.raise("mix deps.audit found vulnerable dependencies (see output above)")
    end
  end
end
