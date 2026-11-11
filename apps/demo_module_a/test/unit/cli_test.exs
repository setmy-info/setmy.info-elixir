defmodule SetmyInfo.DemoModuleA.CliTest do
    @moduledoc """
    Unit tier: the CLI entry point's argument handling and exit statuses, with
    its output captured. The installed launcher (`smi-elixir main`) is shell
    and is exercised by the RPM build, not here.
    """

    use ExUnit.Case, async: true

    import ExUnit.CaptureIO

    alias SetmyInfo.DemoModuleA
    alias SetmyInfo.DemoModuleA.Cli

    test "no argument prints the message and succeeds" do
        assert capture_io(fn -> assert Cli.main([]) == 0 end) ==
                 DemoModuleA.create_message() <> "\n"
    end

    test "--descriptor prints the descriptor map" do
        assert capture_io(fn -> assert Cli.main(["--descriptor"]) == 0 end) ==
                 inspect(DemoModuleA.create_descriptor()) <> "\n"
    end

    test "--help prints the usage on stdout" do
        assert capture_io(fn -> assert Cli.main(["--help"]) == 0 end) =~ "Usage: smi-demo-module-a"
    end

    test "an unknown argument prints the usage on stderr and exits 2" do
        assert capture_io(:stderr, fn -> assert Cli.main(["--nope"]) == 2 end) =~ "Usage:"
    end
end
