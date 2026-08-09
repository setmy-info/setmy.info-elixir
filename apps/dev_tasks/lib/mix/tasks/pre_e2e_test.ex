defmodule Mix.Tasks.PreE2eTest do
  use Mix.Task

  @shortdoc "Starts the running-instance server for every app that has one (§2 row 12, e2e tier)"

  @moduledoc """
  Pre-e2e-test phase (§2 row 12, same always()-cleanup shape as rows 9-11).
  Starts a `mix server` instance for each app that has one - see
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
