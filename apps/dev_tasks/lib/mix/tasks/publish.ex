defmodule Mix.Tasks.Publish do
  use Mix.Task

  @shortdoc "Publish phase (§2 row 20): local-build-only unless HEX_API_KEY is set"

  @moduledoc """
  `mix hex.publish` per app, gated the same way as the JS/Python sides
  (§10.1): dry-run by default, real publish only when `HEX_API_KEY` is set.

  `mix hex.publish --dry-run --yes` looked like the right native flag (its
  own help text: "Builds package and performs local checks without
  publishing"), but verified directly - not assumed - that it still tries to
  refresh/prompt for Hex authentication before ever reaching the "no
  publish" part, and hangs indefinitely waiting on stdin when there's no TTY
  (confirmed: it blocked for a full 2-minute timeout run non-interactively).
  `--yes` only skips the confirm-to-publish prompt, not the
  authenticate-now prompt. So the safe default here never calls
  `mix hex.publish` at all - it reuses `mix hex.build` (Package's own local
  -only validation, no network/auth touched) and just logs what branch/app
  would have published. Only when `HEX_API_KEY` is actually set does this
  call the real `mix hex.publish --yes`, with the key exported so Hex
  authenticates from the env var instead of prompting.

  Only apps Package actually produced a `.tar` for (demo_module_a,
  demo_module_b) are publishable here - see Package's @moduledoc for why
  demo_module_c/demo_module_d are structurally excluded.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    branch = resolve_branch()

    if publish_branch?(branch) do
      Enum.each(WorkspaceHelper.demo_apps_in_order(), &publish_app(&1, branch))
    else
      Mix.shell().info(
        "Skipping publish: branch #{inspect(branch)} is not a publish branch (master/devel*)."
      )
    end
  end

  # master or devel* only, NOT release* - matching the Jenkinsfile's own
  # `when` conditions exactly (Publish/Release needs `branch 'master'`,
  # Publish/Snapshot needs `startsWith('devel')`; neither matches a
  # release* branch name, so real Jenkins runs no Publish stage there
  # either - see release-branch.sh's own comment for the same quirk,
  # already documented on the JS/Python sides). An earlier version of this
  # check also included "release" here, inconsistent with the Jenkinsfile
  # it's supposed to mirror - caught by comparing the two side by side
  # while writing ci-local/release-branch.sh, not assumed correct.
  defp publish_branch?(branch) do
    branch == "master" or String.starts_with?(branch, "devel")
  end

  defp resolve_branch do
    System.get_env("BRANCH_NAME") || System.get_env("CI_BRANCH_NAME") ||
      case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], stderr_to_stdout: true) do
        {output, 0} -> String.trim(output)
        _ -> "unknown"
      end
  end

  defp publish_app(app, branch) do
    dist_name = "setmy_info_#{app.name}"
    artifacts_dir = Path.join([WorkspaceHelper.root_dir(), ".artifacts", dist_name])

    if artifacts_dir |> Path.join("*.tar") |> Path.wildcard() != [] do
      hex_api_key = System.get_env("HEX_API_KEY")
      mix_bin = System.find_executable("mix") || Mix.raise("mix executable not found on PATH")

      if hex_api_key in [nil, ""] do
        Mix.shell().info(
          "Dry-run publishing #{app.name} (branch #{branch}) - local build only, no network"
        )

        run_mix!(mix_bin, ["hex.build"], app.path, [])
      else
        Mix.shell().info("Publishing #{app.name} (branch #{branch})")

        run_mix!(mix_bin, ["hex.publish", "--yes"], app.path, [{"HEX_API_KEY", hex_api_key}])
      end
    else
      Mix.shell().info("No packaged tarball to publish for #{app.name} (run package first)")
    end
  end

  defp run_mix!(mix_bin, args, cwd, env) do
    {output, exit_code} = System.cmd(mix_bin, args, cd: cwd, stderr_to_stdout: true, env: env)
    Mix.shell().info(output)

    if exit_code != 0 do
      Mix.raise("mix #{Enum.join(args, " ")} failed with exit code #{exit_code}")
    end
  end
end
