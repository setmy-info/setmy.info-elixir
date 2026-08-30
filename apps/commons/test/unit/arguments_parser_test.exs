defmodule SetmyInfo.Commons.Arguments.ParserTest do
    @moduledoc """
    Unit tier (ADR-0031: pure, no environment, no files). Port of clj-commons'
    `info.setmy.arguments.parser-test` and python-commons' `TestParser`, which
    test the same parser through their two different CLI libraries.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.Commons.Arguments.{Argument, Config, Constants, ParsedArguments, Parser}
    alias SetmyInfo.Commons.String.Operations

    describe "parse_arguments/2" do
        test "parses smi options, keeps positionals, reports the rest (clj-commons parity)" do
            args = [
                "sub-command",
                "-i",
                "input.txt",
                "-o",
                "output.txt",
                "--smi-profiles",
                "profile1,profile2",
                "--smi-config-paths",
                "./src/test/resourses,./src/main/resourses"
            ]

            config =
                Config.new("Test CLI", [
                    Constants.smi_profiles_argument(),
                    Constants.smi_config_paths_argument(),
                    Argument.new("some-other", "s", &Operations.split_and_trim/1, "Explanation."),
                    Argument.new("another-other", "a", &Operations.split_and_trim/1, "Explanation.", true)
                ])

            parsed = Parser.parse_arguments(args, config)

            assert parsed.options == %{
                              smi_profiles: ["profile1", "profile2"],
                              smi_config_paths: ["./src/test/resourses", "./src/main/resourses"]
                          }

            # clj-commons gets ["sub-command" "input.txt" "output.txt"] here:
            # `clojure.tools.cli` keeps the token after an undeclared option as a
            # positional, `OptionParser` swallows it. See the parser's moduledoc.
            assert parsed.arguments == ["sub-command"]

            assert parsed.errors == [
                              {:unknown_option, "-i"},
                              {:unknown_option, "-o"},
                              {:missing_required, "--another-other"}
                          ]

            assert ParsedArguments.format_errors(parsed) == [
                              ~s(Unknown option: "-i"),
                              ~s(Unknown option: "-o"),
                              ~s(Missing required option: "--another-other")
                          ]
        end

        test "parses declared options by short flag and long flag (python-commons parity)" do
            args = ["-i", "input.txt", "-o", "output.txt", "--smi-profiles", "profile1,profile2"]

            config =
                Config.new("Example parser", [
                    Argument.new("input", "i", &Function.identity/1, "Input file", true),
                    Argument.new("output", "o", &Function.identity/1, "Output file", true),
                    Constants.smi_profiles_argument()
                ])

            parsed = Parser.parse_arguments(args, config)

            assert parsed.options.input == "input.txt"
            assert parsed.options.output == "output.txt"
            assert parsed.options.smi_profiles == ["profile1", "profile2"]
            assert parsed.errors == []
        end

        test "the last occurrence of a repeated option wins" do
            config = Config.new("Test CLI", [Constants.smi_name_argument()])

            parsed = Parser.parse_arguments(["--smi-name", "first", "--smi-name", "second"], config)

            assert parsed.options.smi_name == "second"
        end

        test "summary lists every declared option" do
            config = Config.new("Test CLI", Constants.smi_arguments())

            summary = Parser.parse_arguments([], config).summary

            assert summary =~ "-p, --smi-profiles"
            assert summary =~ "-c, --smi-config-paths  Comma separated config paths."
            assert summary =~ "-o, --smi-optional-config-files"
            assert summary =~ "-n, --smi-name  Application name."
        end
    end

    describe "find_option_value/2" do
        test "finds both --flag value and --flag=value forms" do
            assert Parser.find_option_value(["--smi-server-port", "9090"], "--smi-server-port") ==
                              "9090"

            assert Parser.find_option_value(["--smi-server-port=9090"], "--smi-server-port") == "9090"
        end

        test "the last occurrence wins" do
            argv = ["--smi-server-port", "1", "--smi-server-port=2"]

            assert Parser.find_option_value(argv, "--smi-server-port") == "2"
        end

        test "a flag with no value, a missing flag and a prefix-only match yield nil" do
            assert Parser.find_option_value(["--smi-server-port", "--other"], "--smi-server-port") ==
                              nil

            assert Parser.find_option_value(["--smi-server-port"], "--smi-server-port") == nil
            assert Parser.find_option_value(["--other", "x"], "--smi-server-port") == nil
            assert Parser.find_option_value(["--smi-server-portal", "x"], "--smi-server-port") == nil
        end
    end
end
