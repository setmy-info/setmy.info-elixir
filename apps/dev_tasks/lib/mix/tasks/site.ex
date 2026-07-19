defmodule Mix.Tasks.Site do
  use Mix.Task

  @shortdoc "Site phase (§2 row 22; §8 in full): docs + lint/coverage/security/dependency reports"

  @moduledoc """
  Root-level, not per-app - `mix docs` (ExDoc) is naturally umbrella-aware
  and already produces one combined doc site covering every app's public
  modules in one pass (verified directly: running `mix docs` from the root
  picked up all four `SetmyInfo.DemoModule*` modules automatically, no
  per-app wrapper needed). Genuinely different from the JS/Python sides'
  per-module site generation - a real Elixir/ExDoc structural difference,
  not a shortcut. The other §8.1 report categories (lint, dependency tree,
  SBOM) are root-level too and gathered alongside it into `docs/reports/`.

  Security (Sobelow) is the one exception - it refuses to run at an
  umbrella root at all ("This does not appear to be a Phoenix application.
  If this is an Umbrella application, each application should be scanned
  separately" - confirmed by running it there first, not assumed), so it's
  captured once per demo app instead, same as `mix dialyzer`'s per-app
  constraint (see demo_module_b's mix.exs).
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("docs")

    root = WorkspaceHelper.root_dir()
    reports_dir = Path.join([root, "docs", "reports"])
    File.mkdir_p!(reports_dir)

    mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")

    write_report(reports_dir, "lint.txt", capture(mix_bin, ["credo", "--strict"], root))
    write_report(reports_dir, "dependency-tree.txt", capture(mix_bin, ["deps.tree"], root))
    write_report(reports_dir, "security.txt", security_report(mix_bin))

    sbom_path = Path.join([root, ".artifacts", "sbom.json"])
    sbom_link = if File.exists?(sbom_path), do: "../../.artifacts/sbom.json", else: nil

    write_index(reports_dir, sbom_link)
    Mix.shell().info("Created #{Path.join(reports_dir, "index.html")}")
  end

  defp security_report(mix_bin) do
    WorkspaceHelper.demo_apps_in_order()
    |> Enum.map_join("\n\n", fn app ->
      "=== #{app.name} ===\n" <> capture(mix_bin, ["sobelow", "--config"], app.path)
    end)
  end

  defp capture(mix_bin, args, cwd) do
    {output, _exit_code} = System.cmd(mix_bin, args, cd: cwd, stderr_to_stdout: true)
    output
  end

  defp write_report(dir, name, content) do
    File.write!(Path.join(dir, name), content)
  end

  defp write_index(reports_dir, sbom_link) do
    sbom_item =
      if sbom_link, do: ~s(<li><a href="#{sbom_link}">SBOM</a></li>), else: ""

    File.write!(Path.join(reports_dir, "index.html"), """
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8" /><title>setmy.info-elixir - reports</title></head>
      <body>
        <h1>setmy.info-elixir - reports</h1>
        <ul>
          <li><a href="../index.html">API docs (ExDoc)</a></li>
          <li><a href="./lint.txt">Lint report (Credo)</a></li>
          <li><a href="./security.txt">Security report (Sobelow, per app)</a></li>
          <li><a href="./dependency-tree.txt">Dependency tree</a></li>
          #{sbom_item}
        </ul>
      </body>
    </html>
    """)
  end
end
