defmodule Mix.Tasks.Deploy do
  use Mix.Task

  @shortdoc "Deploy phase (§2 row 21): prepared-not-executed deployment descriptor"

  @moduledoc """
  Direct mirror of `tools/deploy.js` / `scripts/deploy.py`: same
  DEPLOY_TARGET validation, same descriptor shape, same
  "prepared-not-executed" default status - no real target infrastructure
  exists yet, same as the JS/Python sides.

      DEPLOY_TARGET=dev mix deploy
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @deploy_targets ~w(dev test prelive live)

  @impl Mix.Task
  def run(_args) do
    target = System.get_env("DEPLOY_TARGET")

    unless target in @deploy_targets do
      Mix.raise(
        "Missing or invalid DEPLOY_TARGET #{inspect(target)}. Set DEPLOY_TARGET to one of " <>
          "(ADR-0041): #{Enum.join(@deploy_targets, ", ")}. Example: DEPLOY_TARGET=dev mix deploy"
      )
    end

    Enum.each(WorkspaceHelper.demo_apps_in_order(), &deploy_app(&1, target))
  end

  defp deploy_app(app, target) do
    dist_name = "setmy_info_#{app.name}"
    deployment_dir = Path.join([WorkspaceHelper.root_dir(), ".deploy", dist_name, target])
    descriptor_path = Path.join(deployment_dir, "deploy.json")

    File.mkdir_p!(deployment_dir)

    descriptor = %{
      "distName" => dist_name,
      "target" => target,
      "generatedAt" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "deployment" => %{
        "strategy" => "install-hex-tarball",
        "status" => "prepared-not-executed"
      }
    }

    File.write!(descriptor_path, [:json.encode(descriptor), "\n"])

    Mix.shell().info(
      "Prepared deployment descriptor for target #{inspect(target)} at #{descriptor_path}"
    )
  end
end
