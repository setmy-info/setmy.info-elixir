defmodule Mix.Tasks.PreIntegrationTest do
  use Mix.Task

  @shortdoc "Starts the running-instance server for every app that has one (§2 row 9)"

  @moduledoc """
  Pre-integration-test phase (§2 row 9, "gate", always()-cleanup paired with
  `mix post_integration_test`). Starts a `mix server` instance for each app
  that has one - i.e. a `:port` in `config/config.exs`, see
  `SetmyInfo.Build.WorkspaceHelper.server_apps_in_order/1`.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @impl Mix.Task
  def run(_args) do
    Enum.each(WorkspaceHelper.server_apps_in_order(), fn app ->
      Mix.Task.rerun("server", ["start", "--app", to_string(app.name)])
    end)
  end
end
