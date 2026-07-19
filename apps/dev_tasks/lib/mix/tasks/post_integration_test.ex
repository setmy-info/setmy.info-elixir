defmodule Mix.Tasks.PostIntegrationTest do
  use Mix.Task

  @shortdoc "Stops the running-instance server for every demo app (§2 row 11, always())"

  @moduledoc """
  Post-integration-test phase (§2 row 11, "always(), never skipped" - §7.4).
  Stops each demo app's `mix server` instance.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), fn app ->
      Mix.Task.rerun("server", ["stop", "--app", to_string(app.name)])
    end)
  end
end
