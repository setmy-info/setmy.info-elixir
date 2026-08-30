defmodule SetmyInfo.Commons.Config.ApplicationTest do
    @moduledoc """
    Unit tier (ADR-0031): only `Config.Application`'s pure helpers. Everything
    that reads files or the environment lives in
    `test/integration/config_application_test.exs`, the same split
    clj-commons' `application_it.clj` / python-commons' `it_application.py`
    already make by naming themselves integration tests.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.Commons.Config.Application, as: ConfigApplication

    describe "find_last_not_none_and_empty/1" do
        test "returns the last non-empty list" do
            assert ConfigApplication.find_last_not_none_and_empty([nil, ["1", "2"], nil, ["3", "4"]]) ==
                              ["3", "4"]

            assert ConfigApplication.find_last_not_none_and_empty([nil, nil, nil]) == []
            assert ConfigApplication.find_last_not_none_and_empty([["a"], []]) == ["a"]
            assert ConfigApplication.find_last_not_none_and_empty([]) == []
        end
    end

    describe "merge_maps/2" do
        test "merges nested maps rather than replacing them" do
            left = %{"a" => %{"b" => 1, "c" => 2}, "keep" => true}
            right = %{"a" => %{"c" => 3, "d" => 4}}

            assert ConfigApplication.merge_maps(left, right) ==
                              %{"a" => %{"b" => 1, "c" => 3, "d" => 4}, "keep" => true}
        end

        test "a scalar on the right replaces a map on the left" do
            assert ConfigApplication.merge_maps(%{"a" => %{"b" => 1}}, %{"a" => "scalar"}) ==
                              %{"a" => "scalar"}
        end

        test "nil on the right keeps the left side, so an unparseable file is skipped" do
            assert ConfigApplication.merge_maps(%{"a" => 1}, nil) == %{"a" => 1}
        end
    end

    describe "merge_config/1" do
        test "folds the parsed file contents in load order" do
            contents = [
                {"application.yaml", %{"smi" => %{"port" => 8080, "host" => "localhost"}}},
                {"application-local.yaml", %{"smi" => %{"host" => "127.0.0.1"}}},
                {"broken.yaml", nil}
            ]

            assert ConfigApplication.merge_config(contents) ==
                              %{"smi" => %{"port" => 8080, "host" => "127.0.0.1"}}
        end

        test "no files yields an empty configuration" do
            assert ConfigApplication.merge_config([]) == %{}
        end
    end

    describe "get_config_app_name/1" do
        test "reads application.name when present" do
            assert ConfigApplication.get_config_app_name(%{"application" => %{"name" => "svc"}}) ==
                              "svc"
        end

        test "yields nil when absent or not a map" do
            assert ConfigApplication.get_config_app_name(%{}) == nil
            assert ConfigApplication.get_config_app_name(%{"application" => "svc"}) == nil
        end
    end

    describe "parse_file_by_type/1" do
        test "an unknown extension parses to nil without touching the filesystem" do
            assert ConfigApplication.parse_file_by_type("application.properties") == nil
            assert ConfigApplication.parse_file_by_type("application.txt") == nil
        end
    end

    describe "get/3" do
        test "reads by path, falling back to the default" do
            app = %ConfigApplication{merged_configuration: %{"smi" => %{"server" => %{"port" => 8080}}}}

            assert ConfigApplication.get(app, ["smi", "server", "port"]) == 8080
            assert ConfigApplication.get(app, ["smi", "server", "timeout"], 30) == 30
            assert ConfigApplication.get(app, ["missing"]) == nil
        end
    end
end
