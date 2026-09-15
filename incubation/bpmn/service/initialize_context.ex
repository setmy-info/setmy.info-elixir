defmodule Bpmn.Workflow.ParallelPing.Handlers.InitializeContext do
  @moduledoc """
  Step 1: seed the process context.

  `hosts` is the input collection of the multi-instance `ping_localhost` task
  (Modeler: Multi-instance -> Input collection `=hosts`, Input element `host`).
  One parallel instance is started per list element. Hard-coded for now;
  later this can come from a database or a DVB host query.
  """

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok,
     %{
       "hosts" => ["localhost", "localhost", "localhost"],
       "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "started_at_ms" => System.system_time(:millisecond)
     }}
  end
end
