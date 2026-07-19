defmodule Mix.Tasks.Sbom do
  use Mix.Task

  @shortdoc "SBOM phase (§2 row 17): hand-rolled CycloneDX-shaped placeholder"

  @moduledoc """
  Root-level, not per-app: one shared `mix.lock` for the whole umbrella (all
  apps' `deps_path`/`lockfile` point at the root), same reasoning as the
  Python side's shared-venv SBOM/security - one resolved dependency set, not
  one per app.

  Hand-rolled CycloneDX-shaped JSON, explicitly labeled placeholder (§11.2
  allows this) - no actively-maintained real CycloneDX generator was found
  for Elixir/Hex, unlike the Python side which got a real one
  (`cyclonedx-py`). Same acceptable-placeholder territory as the JS side's
  own SBOM.
  """

  alias Mix.Dep.Lock
  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    # Lock.read/0, not Code.eval_file(mix.lock) - the latter works but emits
    # a stream of spurious "quoted keyword" compiler warnings for every
    # entry (mix.lock's string-keyed map literal looks keyword-like to the
    # parser's heuristic); Mix's own accessor avoids that noise entirely.
    locked = Lock.read()

    components =
      Enum.map(locked, fn {name, spec} ->
        %{
          "name" => to_string(name),
          "version" => lock_entry_version(spec),
          "type" => "library"
        }
      end)

    sbom = %{
      "bomFormat" => "CycloneDX",
      "specVersion" => "1.5",
      "metadata" => %{
        "component" => %{"name" => "setmy.info-elixir", "type" => "library"}
      },
      "components" => components
    }

    out_path = Path.join([WorkspaceHelper.root_dir(), ".artifacts", "sbom.json"])
    File.mkdir_p!(Path.dirname(out_path))
    File.write!(out_path, [:json.encode(sbom), "\n"])
    Mix.shell().info("Created #{out_path}")
  end

  defp lock_entry_version(spec) when is_tuple(spec) and tuple_size(spec) >= 3, do: elem(spec, 2)
  defp lock_entry_version(_spec), do: "unknown"
end
