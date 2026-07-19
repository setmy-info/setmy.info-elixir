defmodule Mix.Tasks.PreIntegrationTest do
  use Mix.Task

  @shortdoc "Starts the running-instance server for every demo app (§2 row 9)"

  @moduledoc """
  Pre-integration-test phase (§2 row 9, "gate", always()-cleanup paired with
  `mix post_integration_test`). Starts each demo app's `mix server` instance.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.demo_apps_in_order(), fn app ->
      Mix.Task.rerun("server", ["start", "--app", to_string(app.name)])
    end)
  end
end
