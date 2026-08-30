defmodule SetmyInfo.Commons.String.OperationsTest do
    @moduledoc """
    Unit tier (ADR-0031: in-memory only, no environment variables, no files).
    Port of clj-commons' `info.setmy.string.operations-test`, assertion for
    assertion, plus the cases python-commons' own suite adds.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.Commons.String.Operations

    doctest SetmyInfo.Commons.String.Operations

    describe "split_and_trim/2" do
        test "splits untrimmed comma separated values" do
            assert Operations.split_and_trim(" asdfg , bsg, csdg  , dsg  ", Operations.comma_string()) ==
                     ["asdfg", "bsg", "csdg", "dsg"]

            assert Operations.split_and_trim(" asdfg , bsg, csdg  , dsg  ") ==
                     ["asdfg", "bsg", "csdg", "dsg"]
        end
    end

    describe "trim_list/1" do
        test "trims every string in the list" do
            assert Operations.trim_list(["a  ", " b ", "  c  ", "   d"]) == ["a", "b", "c", "d"]
        end
    end

    describe "to_boolean/2" do
        test "converts boolean strings and falls back to the default" do
            assert Operations.to_boolean(nil) == false
            assert Operations.to_boolean(nil, nil) == false
            assert Operations.to_boolean(nil, true) == true
            assert Operations.to_boolean(nil, false) == false
            assert Operations.to_boolean("False") == false
            assert Operations.to_boolean("False", true) == false
            assert Operations.to_boolean("True") == true
            assert Operations.to_boolean("True", false) == true
            assert Operations.to_boolean("yEs") == true
            assert Operations.to_boolean("no") == false
        end

        test "raises on a value that is neither true-ish nor false-ish" do
            assert_raise ArgumentError, "Invalid boolean value", fn ->
                Operations.to_boolean("maybe")
            end
        end
    end

    describe "to_int/2" do
        test "parses whole integers only" do
            assert Operations.to_int(nil) == 0
            assert Operations.to_int(nil, nil) == 0
            assert Operations.to_int(nil, 1) == 1
            assert Operations.to_int("123", 0) == 123
            assert Operations.to_int("123.123", 0) == 0
            assert Operations.to_int("blah", 222) == 222
            assert Operations.to_int("123.123", 321) == 321
            assert Operations.to_int("123.123") == 0
        end
    end

    describe "to_float/2" do
        test "parses floats and integers, rejecting anything else" do
            assert Operations.to_float(nil) == 0.0
            assert Operations.to_float(nil, nil) == 0.0
            assert Operations.to_float(nil, 1.0) == 1.0
            assert Operations.to_float("123", 0.0) == 123.0
            assert Operations.to_float("123#123", 0.0) == 0.0
            assert Operations.to_float("123#123", 321.0) == 321.0
            assert Operations.to_float("123#123") == 0.0
        end
    end

    describe "json_to_object/2" do
        test "parses JSON into a map" do
            assert Operations.json_to_object(nil) == %{}

            assert Operations.json_to_object(~s({"name":"John Doe", "city":"Tallinn"})) == %{
                     "name" => "John Doe",
                     "city" => "Tallinn"
                   }
        end

        test "falls back to the default on invalid JSON" do
            assert Operations.json_to_object("{not json", %{fallback: true}) == %{fallback: true}
        end
    end

    describe "yaml_to_object/2" do
        test "parses YAML into a map" do
            assert Operations.yaml_to_object(nil) == %{}

            assert Operations.yaml_to_object("person:\n    name: John Doe\n    city: Tallinn") == %{
                     "person" => %{"name" => "John Doe", "city" => "Tallinn"}
                   }
        end
    end

    describe "find_named_placeholders/2" do
        test "lists distinct placeholders in first-appearance order" do
            text = "abc ${def} ghi ${jkl} mno ${prs} ${prs}"

            assert Operations.find_named_placeholders(text) == ["def", "jkl", "prs"]
            assert Operations.find_named_placeholders(text, true) == ["def", "jkl", "prs"]

            assert Operations.find_named_placeholders(text, false) == [
                     "${def}",
                     "${jkl}",
                     "${prs}"
                   ]
        end
    end

    describe "replace_named_placeholder/3" do
        test "replaces every occurrence of one placeholder" do
            text = "abc ${def} ghi ${jkl} mno ${prs} ${prs}"

            assert Operations.replace_named_placeholder(text, "jkl", "Hello World") ==
                     "abc ${def} ghi Hello World mno ${prs} ${prs}"

            assert Operations.replace_named_placeholder(text, "prs", "qwerty") ==
                     "abc ${def} ghi ${jkl} mno qwerty qwerty"
        end

        test "a nil replacement erases the placeholder" do
            assert Operations.replace_named_placeholder("a ${b} c", "b", nil) == "a  c"
        end
    end

    describe "combined_list/3" do
        test "an empty input list yields an empty result" do
            assert Operations.combined_list(["A", "B", "C"], [], ":") == []
            assert Operations.combined_list([], ["X", "Y"], ":") == []
        end

        test "a nil-only input list yields an empty result" do
            assert Operations.combined_list(["A", "B", "C"], [nil], ":") == []
            assert Operations.combined_list([nil], ["X", "Y"], ":") == []
        end

        test "joins every pair" do
            assert Operations.combined_list(["A", "B", "C"], ["X", "Y"]) ==
                     ["AX", "AY", "BX", "BY", "CX", "CY"]

            assert Operations.combined_list(["A", "B", "C"], ["X", "Y"], ":") ==
                     ["A:X", "A:Y", "B:X", "B:Y", "C:X", "C:Y"]
        end

        test "skips pairs containing nil" do
            assert Operations.combined_list(["A", "B", "C"], ["X", "Y", nil]) ==
                     ["AX", "AY", "BX", "BY", "CX", "CY"]

            assert Operations.combined_list(["A", "B", "C", nil], ["X", "Y"], ":") ==
                     ["A:X", "A:Y", "B:X", "B:Y", "C:X", "C:Y"]
        end
    end

    describe "combined_by_function_list/4" do
        test "joins every pair the filter accepts" do
            assert Operations.combined_by_function_list(["A", "B", "C"], ["X", "Y"], "", fn _x ->
                     true
                   end) ==
                       ["AX", "AY", "BX", "BY", "CX", "CY"]

            assert Operations.combined_by_function_list(["A", "B", "C"], ["X", "Y"], ":", fn _x ->
                     true
                   end) ==
                       ["A:X", "A:Y", "B:X", "B:Y", "C:X", "C:Y"]
        end

        test "a rejecting filter yields an empty result" do
            assert Operations.combined_by_function_list(["A", "B", "C"], ["X", "Y"], "", fn _x ->
                     false
                   end) == []

            assert Operations.combined_by_function_list(["A", "B", "C"], ["X", "Y"], ":", fn _x ->
                     false
                   end) == []
        end

        test "a missing filter yields an empty result, same as both older rows" do
            assert Operations.combined_by_function_list(["A", "B"], ["X", "Y"], ":") == []
        end

        test "filters on the joined value" do
            reject_cy = fn value -> not Regex.match?(~r/.*[Cc].*[Yy].*/, value) end

            assert Operations.combined_by_function_list(["A", "B", "C"], ["X", "Y"], "", reject_cy) ==
                     ["AX", "AY", "BX", "BY", "CX"]

            assert Operations.combined_by_function_list(["A", "B", "C"], ["X", "Y"], ":", reject_cy) ==
                     ["A:X", "A:Y", "B:X", "B:Y", "C:X"]
        end
    end

    describe "nil_to_default/2" do
        test "replaces nil with the default" do
            assert Operations.nil_to_default(nil) == ""
            assert Operations.nil_to_default(nil, "X") == "X"
            assert Operations.nil_to_default("value", "X") == "value"
        end
    end
end
