defmodule Mix.Tasks.PostIntegrationTest do
  use Mix.Task

  @shortdoc "Stops the running-instance server for every app that has one (§2 row 11, always())"

  @moduledoc """
  Post-integration-test phase (§2 row 11, "always(), never skipped" - §7.4).
  Stops the `mix server` instance of each app that has one - see
  `SetmyInfo.Build.WorkspaceHelper.server_apps_in_order/1`.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.server_apps_in_order(), fn app ->
      Mix.Task.rerun("server", ["stop", "--app", to_string(app.name)])
    end)
  end
end
