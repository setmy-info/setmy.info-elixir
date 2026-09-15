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

    xml = File.read!(bpmn_file)
    diagram = Diagram.load(xml, bpmn_file: bpmn_file, app_name: @app_name)

    [{:bpmn_process, %{id: process_id} = attrs, elements} | _] = diagram.processes
    elements = apply_zeebe_multi_instance(elements, xml)
    process = {:bpmn_process, attrs, elements}

    IO.puts("\n=== #{Map.get(attrs, :name, process_id)} (#{process_id}) ===\n")
    print_discovery(diagram.discovery, bpmn_file)
    print_multi_instance(elements)

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

  # --- Zeebe multi-instance adapter ---
  #
  # Camunda Modeler (Camunda 8 target) stores multi-instance settings as
  #   <zeebe:loopCharacteristics inputCollection="=hosts" inputElement="host"
  #                              outputCollection="pingResults" outputElement="=result"/>
  # rodar only understands the BPMN-standard loopDataInputRef / inputDataItem /
  # outputDataItem, so translate here instead of hand-editing the XML.
  # outputElement cannot be mapped: rodar always collects the value a handler
  # returns under "_mi_current_result".

  defp apply_zeebe_multi_instance(elements, xml) do
    zeebe = zeebe_loop_settings(xml)

    elements
    |> to_element_map()
    |> Map.new(fn
      {id, {type, %{loop_characteristics: %{type: :multi_instance} = loop} = attrs}}
      when is_map_key(zeebe, id) ->
        z = zeebe[id]

        loop =
          loop
          |> put_if_nil(:loopDataInputRef, strip_feel(z["inputCollection"]))
          |> put_if_nil(:inputDataItem, z["inputElement"])
          |> put_if_nil(:outputDataItem, z["outputCollection"])

        {id, {type, %{attrs | loop_characteristics: loop}}}

      other ->
        other
    end)
  end

  defp to_element_map(elements) when is_map(elements), do: elements

  defp to_element_map(elements) when is_list(elements) do
    Map.new(elements, fn {_type, %{id: id}} = elem -> {id, elem} end)
  end

  defp put_if_nil(map, _key, nil), do: map
  defp put_if_nil(map, key, value), do: Map.update(map, key, value, &(&1 || value))

  defp strip_feel(nil), do: nil
  defp strip_feel("=" <> expr), do: String.trim(expr)
  defp strip_feel(expr), do: String.trim(expr)

  # Returns %{task_id => %{"inputCollection" => ..., ...}} for every element that
  # has a multiInstanceLoopCharacteristics with a zeebe:loopCharacteristics inside.
  defp zeebe_loop_settings(xml) do
    # erlsom applies nameFun to attribute names too (with an empty prefix).
    name_fun = fn
      name, _ns, prefix when prefix in [[], ""] -> to_string(name)
      name, _ns, prefix -> "#{prefix}:#{name}"
    end

    {:ok, tree, _} = :erlsom.simple_form(xml, nameFun: name_fun)
    collect_zeebe_loops(tree, %{})
  end

  defp collect_zeebe_loops({_tag, attrs, children}, acc) when is_list(children) do
    acc =
      with id when is_binary(id) <- attr(attrs, "id"),
           {_, _, mi_children} <- find_child(children, ":multiInstanceLoopCharacteristics"),
           {_, _, ext_children} <- find_child(mi_children, ":extensionElements"),
           {_, z_attrs, _} <- find_child(ext_children, ":loopCharacteristics") do
        Map.put(acc, id, Map.new(z_attrs, fn {k, v} -> {to_string(k), to_string(v)} end))
      else
        _ -> acc
      end

    Enum.reduce(children, acc, &collect_zeebe_loops/2)
  end

  defp collect_zeebe_loops(_text, acc), do: acc

  defp find_child(children, suffix) do
    Enum.find(children, fn
      {tag, _, _} -> String.ends_with?(to_string(tag), suffix)
      _ -> false
    end)
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn {k, v} -> if to_string(k) == name, do: to_string(v) end)
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

  defp print_multi_instance(elements) do
    Enum.each(elements, fn
      {id, {_type, %{loop_characteristics: %{type: :multi_instance} = loop}}} ->
        mode = if loop[:isSequential] == "true", do: "sequential", else: "parallel"

        IO.puts(
          "  multi-instance: #{id} (#{mode}) over #{loop[:loopDataInputRef] || loop[:loopCardinality]}" <>
            " as #{loop[:inputDataItem] || "loopCounter"} -> #{loop[:outputDataItem] || "_mi_results"}\n"
        )

      _ ->
        :ok
    end)
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
