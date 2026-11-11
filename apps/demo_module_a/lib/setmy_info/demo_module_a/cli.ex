defmodule SetmyInfo.DemoModuleA.Cli do
    @moduledoc """
    Command line entry point of `demo_module_a` - the worked example of how a
    CLI tool is installed.

    Installed, it is run by `/opt/setmy.info/bin/smi-demo-module-a`, a short
    shell script that sets up the PATH and the code path and runs the
    installed `elixir` with `-e 'System.halt(SetmyInfo.DemoModuleA.Cli.main(System.argv()))'`.
    A new CLI tool is the same two things: a module with a `main/1` and a
    script naming it (see `src/main/sh/bin/`).

    `main/1` returns the exit status; the script halts the VM with it.
    """

    alias SetmyInfo.DemoModuleA

    @usage """
    Usage: smi-demo-module-a [--descriptor | --help]

      (no option)    print the message of demo_module_a
      --descriptor   print the descriptor map of demo_module_a
      --help         print this help
    """

    @doc """
    Runs the command for `argv` and returns its exit status: 0 on success, 2
    on an unknown argument.
    """
    @spec main([String.t()]) :: non_neg_integer()
    def main(argv) do
        case argv do
            [] ->
                IO.puts(DemoModuleA.create_message())
                0

            ["--descriptor"] ->
                IO.puts(inspect(DemoModuleA.create_descriptor()))
                0

            ["--help"] ->
                IO.write(@usage)
                0

            _ ->
                IO.write(:stderr, @usage)
                2
        end
    end
end
