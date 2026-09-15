#!/usr/bin/env elixir
#
# Standalone BPMN runner (no Mix project needed).
#
#   ./bpmn-run.exs scaffold <process.bpmn>   # generate empty handler modules into ./service
#   ./bpmn-run.exs run      <process.bpmn>   # load ./service/*.ex and execute the process
#
# Handler modules follow rodar's discovery convention:
#   <AppName>.Workflow.<BpmnFileName>.Handlers.<TaskName>
# with AppName fixed to "Bpmn" here, so `run` finds them without any registration code.

Mix.install([
  {:rodar, "~> 1.4.4"}
])

defmodule BpmnRun do
  alias Rodar.Context
  alias Rodar.Engine.Diagram
  alias Rodar.Hooks
  alias Rodar.Scaffold
  alias Rodar.Scaffold.Discovery

  @app_name "Bpmn"
  @service_dir "./service"

  def scaffold(bpmn_file) do
    Mix.Task.run("rodar.scaffold", [
      bpmn_file,
      "--output-dir",
      @service_dir,
      "--module-prefix",
      module_prefix(bpmn_file)
    ])
  end

  def run(bpmn_file) do
    load_handlers()

    diagram =
      bpmn_file
      |> File.read!()
      |> Diagram.load(bpmn_file: bpmn_file, app_name: @app_name)

    [{:bpmn_process, %{id: process_id} = attrs, _elements} = process | _] = diagram.processes

    IO.puts("\n=== #{Map.get(attrs, :name, process_id)} (#{process_id}) ===\n")
    print_discovery(diagram.discovery, bpmn_file)

    # Service task handlers are injected into the diagram by discovery;
    # other task types (user, send, ...) go through the TaskRegistry.
    Rodar.Registry.register(process_id, process)
    Discovery.register_discovered(diagram.discovery)

    {:ok, pid} =
      DynamicSupervisor.start_child(Rodar.ProcessSupervisor, {Rodar.Process, {process_id, %{}}})

    instance_id = Rodar.Process.instance_id(pid)
    context = Rodar.Process.get_context(pid)

    # Make the instance id visible to handlers through the process data.
    Context.put_data(context, "process_instance_id", instance_id)
    # :before_node fires in execution order; :after_node would print in reverse,
    # because rodar releases tokens recursively and unwinds afterwards.
    Hooks.register(context, :before_node, &print_node(&1, context))

    IO.puts("--- Execution (instance #{instance_id}) ---\n")
    :ok = Rodar.Process.activate(pid)

    IO.puts("\n--- Result ---\n")
    IO.puts("  Status: #{Rodar.Workflow.process_status(pid)}")
    IO.puts("  Data:   #{inspect(Rodar.Workflow.process_data(pid), pretty: true)}")
  end

  defp module_prefix(bpmn_file) do
    Scaffold.default_module_prefix(@app_name, Scaffold.bpmn_base_name(bpmn_file))
  end

  defp load_handlers do
    @service_dir
    |> Path.join("*.ex")
    |> Path.wildcard()
    |> Enum.each(&Code.require_file/1)
  end

  defp print_discovery(%{handler_map: hm, task_registry_entries: tre, not_found: nf}, bpmn_file) do
    Enum.each(Map.to_list(hm) ++ tre, fn {id, mod} ->
      IO.puts("  handler: #{id} -> #{inspect(mod)}")
    end)

    Enum.each(nf, fn entry ->
      IO.puts("  MISSING handler for #{inspect(entry)} (run: ./bpmn-run.exs scaffold #{bpmn_file})")
    end)

    IO.puts("")
  end

  defp print_node(%{node_type: :bpmn_sequence_flow}, _context), do: :ok

  defp print_node(%{node_id: id, node_type: type}, context) do
    name =
      case Map.get(Context.get(context, :process), id) do
        {_, %{name: n}} when is_binary(n) and n != "" -> n
        _ -> id
      end

    IO.puts("  -> #{type}: #{name}")
  end
end

case System.argv() do
  ["scaffold", bpmn_file] ->
    BpmnRun.scaffold(bpmn_file)

  ["run", bpmn_file] ->
    BpmnRun.run(bpmn_file)

  _ ->
    IO.puts("""
    Usage:

      ./bpmn-run.exs scaffold <process.bpmn>
      ./bpmn-run.exs run      <process.bpmn>
    """)

    System.halt(1)
end
