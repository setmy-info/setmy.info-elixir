defmodule Mix.Tasks.Verify do
  use Mix.Task

  @shortdoc "Verify phase (§2 row 15): confirms Build's compiled output exists"

  @moduledoc """
  Confirms the Build phase's actual output (compiled .beam files under
  `_build/<env>/lib/<app>/ebin/`) exists - mirrors `tools/verify.js` /
  `scripts/verify.py`, checking Build's output rather than Package's (which
  hasn't run yet at this point in the sequence).
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), &verify_app/1)
  end

  defp verify_app(app) do
    ebin_dir =
      Path.join([
        WorkspaceHelper.root_dir(),
        "_build",
        to_string(Mix.env()),
        "lib",
        to_string(app.name),
        "ebin"
      ])

    beam_files =
      if File.dir?(ebin_dir), do: Path.wildcard(Path.join(ebin_dir, "*.beam")), else: []

    if beam_files == [] do
      Mix.raise("Missing build artifacts for #{app.name}: no .beam files under #{ebin_dir}")
    end

    Mix.shell().info("Verified build artifacts for #{app.name}")
  end
end
