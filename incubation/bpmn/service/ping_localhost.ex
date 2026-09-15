defmodule Bpmn.Workflow.ParallelPing.Handlers.PingLocalhost do
  @moduledoc """
  Step 2: runs `count` times in parallel (BPMN multi-instance, isSequential=false).

  Each instance pings localhost once. The value put under `_mi_current_result`
  is what rodar collects into the `_mi_results` list once all instances finish.
  Note: rodar shares one context between parallel instances, so `loopCounter`
  is only an approximation of "which instance am I".
  """

  @behaviour Rodar.Activity.Task.Service.Handler

  @host "localhost"

  @impl true
  def execute(_attrs, data) do
    {micros, ok?} = :timer.tc(fn -> ping(@host) end)

    {:ok,
     %{
       "_mi_current_result" => %{
         "host" => @host,
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
