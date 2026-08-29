defmodule SetmyInfo.Commons.Environment.VariablesIntegrationTest do
  @moduledoc """
  Integration tier (ADR-0031 marks environment variables as an IT
  dependency). Covers what clj-commons leaves untested and python-commons
  tests through behave instead - the Cucumber-level scenarios are ported
  separately in `test/e2e/environment_variables_test.exs`.
  """

  use SetmyInfo.Commons.EnvironmentCase, async: false

  @moduletag :integration

  alias SetmyInfo.Commons.Config.Overrides
  alias SetmyInfo.Commons.Environment.Variables

  test "set, get and delete round trip" do
    Variables.set_environment_variable("SMI_TEST_ROUND_TRIP", "value")
    assert Variables.get_environment_variable("SMI_TEST_ROUND_TRIP") == "value"

    Variables.delete_environment_variable("SMI_TEST_ROUND_TRIP")
    assert Variables.get_environment_variable("SMI_TEST_ROUND_TRIP") == nil
  end

  test "typed readers" do
    put_environment(%{
      "SMI_TEST_BOOLEAN" => "TRUE",
      "SMI_TEST_INT" => "1234",
      "SMI_TEST_FLOAT" => "1234.5678",
      "SMI_TEST_JSON" => ~s({"name": "John", "age": 30})
    })

    assert Variables.get_boolean_environment_variable("SMI_TEST_BOOLEAN") == true
    assert Variables.get_int_environment_variable("SMI_TEST_INT") == 1234
    assert Variables.get_float_environment_variable("SMI_TEST_FLOAT") == 1234.5678

    assert Variables.get_json_environment_variable("SMI_TEST_JSON") ==
             %{"name" => "John", "age" => 30}
  end

  test "typed readers fall back when the variable is unset" do
    assert Variables.get_boolean_environment_variable("SMI_TEST_ABSENT") == false
    assert Variables.get_int_environment_variable("SMI_TEST_ABSENT") == 0
    assert Variables.get_float_environment_variable("SMI_TEST_ABSENT") == 0.0
    assert Variables.get_json_environment_variable("SMI_TEST_ABSENT") == %{}
  end

  describe "get_environment_variables_list/2" do
    test "splits, trims and drops empty fragments" do
      put_environment(%{"SMI_TEST_LIST" => " abc , def , ghi   "})

      assert Variables.get_environment_variables_list("SMI_TEST_LIST") == ["abc", "def", "ghi"]
    end

    test "an unset or empty variable yields an empty list" do
      put_environment(%{"SMI_TEST_EMPTY" => ""})

      assert Variables.get_environment_variables_list("SMI_TEST_ABSENT") == []
      assert Variables.get_environment_variables_list(nil) == []
      assert Variables.get_environment_variables_list("SMI_TEST_EMPTY") == []
    end

    test "accepts both the one-arity and the two-arity parse function shape" do
      put_environment(%{"SMI_TEST_LIST" => "a,b"})

      assert Variables.get_environment_variables_list("SMI_TEST_LIST", &String.upcase/1) ==
               ["A", "B"]

      assert Variables.get_environment_variables_list("SMI_TEST_LIST", fn value, index ->
               {index, value}
             end) == [{0, "a"}, {1, "b"}]
    end
  end

  describe "environment_overrides/2 against the real environment" do
    test "never consumes the four SMI_* control variables as values" do
      config = %{"smi" => %{"profiles" => "from-yaml", "name" => "from-yaml"}}

      put_environment(%{"SMI_PROFILES" => "dev", "SMI_NAME" => "from-env"})

      assert Overrides.environment_overrides(config, ["smi"]) == %{}
    end

    test "reads a real variable for a real configured key" do
      config = %{"smi" => %{"server" => %{"port" => 8080}}}

      put_environment(%{"SMI_SERVER_PORT" => "9090"})

      assert Overrides.environment_overrides(config, ["smi"]) ==
               %{["smi", "server", "port"] => 9090}
    end
  end
end
