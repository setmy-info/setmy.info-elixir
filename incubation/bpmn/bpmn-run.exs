#!/usr/bin/env elixir

Mix.install([
  {:rodar, "~> 1.4.4"}
])

case System.argv() do
  ["scaffold", bpmn_file] ->
    Mix.Task.run("rodar.scaffold", [
      bpmn_file,
      "--output-dir",
      "./service"
    ])

  ["run", bpmn_file] ->
    Mix.Task.run("rodar.run", [
      bpmn_file
    ])

  _ ->
    IO.puts("""
    Usage:

      ./bpmn-run.exs scaffold <process.bpmn>
      ./bpmn-run.exs run      <process.bpmn>
    """)

    System.halt(1)
end
