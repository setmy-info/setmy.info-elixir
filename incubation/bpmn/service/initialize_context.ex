defmodule Bpmn.Workflow.ParallelPing.Handlers.InitializeContext do
  @moduledoc """
  Step 1: seed the process context.

  `count` decides how many parallel `ping_localhost` instances the BPMN
  multi-instance task spawns (see `loopCardinality` in the .bpmn file).
  In real life this step would e.g. ask a DVB host list and set
  `count` to its length. Here it is hard-coded to 3.
  """

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok,
     %{
       "count" => 3,
       "started_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "started_at_ms" => System.system_time(:millisecond)
     }}
  end
end
