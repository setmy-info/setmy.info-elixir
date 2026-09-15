defmodule Bpmn.Workflow.ParallelPing.Handlers.PingLocalhost do
  @moduledoc """
  Step 2: one instance per element of `hosts`, all running in parallel.

  The current element arrives as `host` (Modeler: Input element). The value
  returned under `_mi_current_result` is what rodar appends to the output
  collection (`pingResults`) once every instance has finished.
  Note: rodar shares one context between parallel instances, so `host` and
  `loopCounter` are only reliable when the instances start far enough apart.
  """

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, data) do
    host = data["host"] || "localhost"
    {micros, ok?} = :timer.tc(fn -> ping(host) end)

    {:ok,
     %{
       "_mi_current_result" => %{
         "host" => host,
         "ok" => ok?,
         "loop" => data["loopCounter"],
         "took_ms" => div(micros, 1000)
       }
     }}
  end

  defp ping(host) do
    case System.find_executable("ping") do
      nil ->
        # No ping binary: simulate some work instead of failing the process.
        Process.sleep(100)
        false

      ping ->
        {_out, exit_code} = System.cmd(ping, ["-c", "1", "-W", "2", host], stderr_to_stdout: true)
        exit_code == 0
    end
  end
end
