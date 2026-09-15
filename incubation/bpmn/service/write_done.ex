defmodule Bpmn.Workflow.ParallelPing.Handlers.WriteDone do
  @moduledoc """
  Step 3: runs after all parallel pings finished.

  Writes `results/<process instance id>.txt` with the time spent since
  `initialize_context` stored `started_at_ms`.
  """

  @behaviour Rodar.Activity.Task.Service.Handler

  @results_dir "results"

  @impl true
  def execute(_attrs, data) do
    instance_id = data["process_instance_id"] || "unknown"
    spent_ms = System.system_time(:millisecond) - data["started_at_ms"]
    results = data["pingResults"] || []
    path = Path.join(@results_dir, "#{instance_id}.txt")

    File.mkdir_p!(@results_dir)

    File.write!(path, """
    process instance: #{instance_id}
    started at:       #{data["started_at"]}
    finished at:      #{DateTime.utc_now() |> DateTime.to_iso8601()}
    parallel pings:   #{length(results)} finished, #{length(data["hosts"] || [])} requested
    ping results:     #{inspect(results)}
    time spent:       #{spent_ms} ms
    """)

    {:ok, %{"result_file" => path, "spent_ms" => spent_ms}}
  end
end
