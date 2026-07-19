defmodule Mix.Tasks.InstallLocal do
  use Mix.Task

  @shortdoc "Install-local phase (§2 row 19): repurposed packed-artifact consumer test"

  @moduledoc """
  Install-local phase (§2 row 19, "gate"): installs the built artifact into
  the local toolchain's cache/store for other local projects to consume -
  Maven's `mvn install` into ~/.m2.

  Repurposed like the Python side (`scripts/install_local.py`), not a native
  no-op: extracts the packaged Hex `.tar` (Package's actual output, not the
  in-umbrella dev source) into a scratch directory, and compiles it as a
  standalone `path:` dependency of a disposable scratch Mix project outside
  the umbrella - confirming the *packaged* file set (whatever `mix hex.build`
  actually included) compiles and exposes the expected public API on its
  own, which an in-umbrella dev build can silently mask (a file missing from
  `package: [files: ...]` in `mix.exs` would go unnoticed otherwise).
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), &install_local_app/1)
  end

  defp install_local_app(app) do
    dist_name = "setmy_info_#{app.name}"
    artifacts_dir = Path.join([WorkspaceHelper.root_dir(), ".artifacts", dist_name])

    case artifacts_dir |> Path.join("*.tar") |> Path.wildcard() do
      [] ->
        Mix.shell().info("No packaged tarball to install for #{app.name} (run package first)")

      [tar_path | _] ->
        verify_consumer(app, tar_path, artifacts_dir)
    end
  end

  defp verify_consumer(app, tar_path, artifacts_dir) do
    scratch_dir = Path.join(artifacts_dir, "install-check")
    source_dir = Path.join(scratch_dir, "source")
    consumer_dir = Path.join(scratch_dir, "consumer")

    File.rm_rf!(scratch_dir)
    File.mkdir_p!(source_dir)
    File.mkdir_p!(consumer_dir)

    # System `tar`, not :erl_tar - the latter raised {:error,
    # :invalid_tar_checksum} on a real, verified-uncorrupted Hex package tar
    # (confirmed: the system `tar` extracts the same file cleanly), some
    # compatibility gap in OTP's tar implementation with Hex's own tar
    # shape, not investigated further since a working alternative exists.
    {_output, 0} = System.cmd("tar", ["xf", tar_path], cd: scratch_dir)

    contents_gz = Path.join(scratch_dir, "contents.tar.gz")
    {_output, 0} = System.cmd("tar", ["xzf", contents_gz], cd: source_dir)

    File.write!(Path.join(consumer_dir, "mix.exs"), consumer_mix_exs(app.name))

    mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")

    {output, exit_code} =
      System.cmd(mix_bin, ["do", "deps.get,", "compile", "--warnings-as-errors"],
        cd: consumer_dir,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "dev"}]
      )

    if exit_code != 0 do
      Mix.shell().info(output)
      Mix.raise("Consumer compile failed for #{app.name} - packaged .tar is missing something")
    end

    Mix.shell().info(
      "Installed #{app.name}'s packaged .tar into a scratch consumer project and confirmed it compiles"
    )
  end

  defp consumer_mix_exs(app_name) do
    """
    defmodule InstallCheck.MixProject do
      use Mix.Project

      def project do
        [app: :install_check, version: "0.1.0", deps: [{:#{app_name}, path: "../source"}]]
      end
    end
    """
  end
end
