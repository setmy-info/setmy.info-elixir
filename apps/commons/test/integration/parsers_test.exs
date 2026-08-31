defmodule SetmyInfo.Commons.Parsers.IntegrationTest do
    @moduledoc """
    Integration tier (ADR-0031: data files and config files are IT
    dependencies). Covers the two file parsers against the real fixtures, and
    the "missing or malformed file is not an exception" contract both older
    rows rely on for candidate-path probing.
    """

    use SetmyInfo.Commons.EnvironmentCase, async: false

    @moduletag :integration

    alias SetmyInfo.Commons.Config.Application, as: ConfigApplication
    alias SetmyInfo.Commons.File.Operations, as: FileOperations
    alias SetmyInfo.Commons.Json.Parser, as: JsonParser
    alias SetmyInfo.Commons.Yaml.Parser, as: YamlParser

    @yaml_fixture "./test/resources/env/application.yaml"

    test "read_file/2 returns the error value for a missing file" do
        assert FileOperations.read_file("./test/resources/nope.yaml") == ""
        assert FileOperations.read_file("./test/resources/nope.yaml", "fallback") == "fallback"
        assert FileOperations.read_file(@yaml_fixture) =~ "env/application.yaml"
    end

    test "parse_yaml_file/2 parses with string keys" do
        assert YamlParser.parse_yaml_file(@yaml_fixture) == %{
                 "application" => %{"name" => "Env Application"},
                 "name" => "./test/resources/env/application.yaml",
                 "d" => %{"e" => %{"f" => "env/application.yaml"}}
               }
    end

    test "parse_yaml_file/2 on a missing file yields an empty map, not a crash" do
        assert YamlParser.parse_yaml_file("./test/resources/nope.yaml") == %{}
    end

    test "post_read_function runs before parsing, so substituted values keep YAML types" do
        post_actions = %{post_read_function: &ConfigApplication.post_read_function/1}

        parsed = YamlParser.parse_yaml_file("./test/resources/application.yaml", post_actions)

        assert get_in(parsed, ["a", "d"]) === 123
        assert get_in(parsed, ["a", "e"]) === 123.456
        assert get_in(parsed, ["a", "f"]) === true
        assert get_in(parsed, ["a", "h"]) == "A AA AAA"
    end

    test "post_parse_function runs after parsing" do
        post_actions = %{post_parse_function: &Map.get(&1, "name")}

        assert YamlParser.parse_yaml_file(@yaml_fixture, post_actions) ==
                 "./test/resources/env/application.yaml"
    end

    test "parse_json_file/2 parses and reports failure as nil" do
        path = Path.join(System.tmp_dir!(), "smi_commons_parsers_test.json")
        File.write!(path, ~s({"smi": {"server": {"port": 8080}}}))
        on_exit(fn -> File.rm(path) end)

        assert JsonParser.parse_json_file(path) == %{"smi" => %{"server" => %{"port" => 8080}}}
        assert JsonParser.parse_json_file("./test/resources/nope.json") == nil
    end

    test "parse_json_file/2 runs both post_actions hooks" do
        path = Path.join(System.tmp_dir!(), "smi_commons_parsers_hooks_test.json")
        File.write!(path, ~s({"port": "${SOME_PORT}"}))
        on_exit(fn -> File.rm(path) end)

        post_actions = %{
            post_read_function: &String.replace(&1, "${SOME_PORT}", "8080"),
            post_parse_function: &Map.get(&1, "port")
        }

        assert JsonParser.parse_json_file(path, post_actions) == "8080"
    end

    # The one place the two file parsers disagree, and the reason both
    # moduledocs carry the comparison: "" is a valid, empty YAML document but
    # is not JSON at all. Pinned here so the docs cannot drift from it.
    test "the parsers agree on invalid content and disagree on a missing file" do
        yaml_path = Path.join(System.tmp_dir!(), "smi_commons_parsers_broken_test.yaml")
        json_path = Path.join(System.tmp_dir!(), "smi_commons_parsers_broken_test.json")
        File.write!(yaml_path, "a: [1, 2\n  b: :::")
        File.write!(json_path, "{not json")

        on_exit(fn ->
            File.rm(yaml_path)
            File.rm(json_path)
        end)

        assert YamlParser.parse_yaml_file(yaml_path) == nil
        assert JsonParser.parse_json_file(json_path) == nil

        assert YamlParser.parse_yaml_file("./test/resources/nope.yaml") == %{}
        assert JsonParser.parse_json_file("./test/resources/nope.json") == nil
    end

    # YAML rarely fails outright - it succeeds with a scalar, which is why
    # merge_config/1 merges maps only.
    test "accidental garbage parses as a YAML scalar rather than failing" do
        path = Path.join(System.tmp_dir!(), "smi_commons_parsers_scalar_test.yaml")
        File.write!(path, "just a bare word")
        on_exit(fn -> File.rm(path) end)

        assert YamlParser.parse_yaml_file(path) == "just a bare word"
    end

    test "parse_file_by_type/1 dispatches on the extension" do
        assert ConfigApplication.parse_file_by_type(@yaml_fixture) |> Map.has_key?("d")
        assert ConfigApplication.parse_file_by_type("./test/resources/application.properties") == nil
    end
end
