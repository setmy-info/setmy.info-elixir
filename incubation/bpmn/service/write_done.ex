defmodule Nil.Workflow.ParallelPing.Handlers.WriteDone do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    # TODO: Implement service task logic
    {:ok, %{}}
  end
end
