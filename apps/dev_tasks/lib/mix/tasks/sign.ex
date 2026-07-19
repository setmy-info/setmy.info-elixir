defmodule Mix.Tasks.Sign do
  use Mix.Task

  @shortdoc "Sign phase (§2 row 18): SHA-256 checksum placeholder"

  @moduledoc """
  SHA-256 checksum placeholder, explicitly not a real cryptographic
  signature - same acceptable-but-labeled placeholder (§11.1) as the
  JS/Python sides, no reason to over-deliver here. Signs Package's actual
  output (the .tar under `.artifacts/<dist-name>/`); apps skipped by
  Package (in-umbrella-dependent ones) have nothing to sign, and are
  skipped here too, silently - not a separate finding, just downstream of
  Package's own skip.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), &sign_app/1)
  end

  defp sign_app(app) do
    dist_name = "setmy_info_#{app.name}"
    artifacts_dir = Path.join([WorkspaceHelper.root_dir(), ".artifacts", dist_name])
    signatures_dir = Path.join([WorkspaceHelper.root_dir(), ".signatures", dist_name])

    # Only *.tar files, not everything in the artifacts dir -
    # install_local.ex leaves an install-check/ directory alongside the tar,
    # and File.read! errors on a directory (hit for real before narrowing
    # this glob, same category of bug the Python side's publish.py hit with
    # its own artifacts-dir glob).
    artifacts_dir
    |> Path.join("*.tar")
    |> Path.wildcard()
    |> case do
      [] ->
        :ok

      tar_paths ->
        File.mkdir_p!(signatures_dir)

        Enum.each(tar_paths, fn tar_path ->
          artifact = Path.basename(tar_path)

          digest =
            tar_path
            |> File.read!()
            |> then(&:crypto.hash(:sha256, &1))
            |> Base.encode16(case: :lower)

          signature_path = Path.join(signatures_dir, "#{artifact}.sha256")
          File.write!(signature_path, "#{digest}  #{artifact}\n")
          Mix.shell().info("Created #{signature_path}")
        end)
    end
  end
end
