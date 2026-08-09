defmodule SetmyInfo.Commons.EnvironmentVariablesE2eTest do
  @moduledoc """
  E2E tier (ADR-0031 puts "Cucumber / Spec by example" here). Scenario for
  scenario port of python-commons'
  `test/features/environment/environment_variables_feature.feature`, whose
  `given`/`when`/`then` steps map onto the same three functions below.

  Documented divergence, same shape as this umbrella's existing e2e tiers:
  no Cucumber runner. `cabbage`/`white_bread` are the BEAM's Gherkin
  options and neither is actively maintained; ExUnit with explicit
  given/when/then helpers keeps the scenarios readable and the dependency
  list honest. clj-commons has no Cucumber layer at all.
  """

  use SetmyInfo.Commons.EnvironmentCase, async: false

  alias SetmyInfo.Commons.Environment.Variables

  defp given_environment_variable(variable_name, variable_value) do
    Variables.set_environment_variable(variable_name, variable_value)
    variable_name
  end

  test "Scenario: Accessing and parsing environment variables" do
    variable_name = given_environment_variable("TEST_ENVIRONMENT_VARIABLE", "abc,def,ghi")

    actual_value = Variables.get_environment_variable(variable_name)

    assert actual_value == "abc,def,ghi"
  end

  test "Scenario: Getting un-trimmed environment variables" do
    variable_name =
      given_environment_variable("TEST_ENVIRONMENT_VARIABLE_2", " abc , def , ghi   ")

    actual_value = Variables.get_environment_variable(variable_name)

    assert actual_value == " abc , def , ghi   "
  end

  test "Scenario: Getting un-trimmed environment variables into trimmed list" do
    variable_name =
      given_environment_variable("TEST_ENVIRONMENT_VARIABLE_3", " abc , def , ghi   ")

    actual_value = Variables.get_environment_variables_list(variable_name)

    assert actual_value == ["abc", "def", "ghi"]
  end

  test "Scenario: Getting un-trimmed boolean environment variable" do
    variable_name = given_environment_variable("TEST_ENVIRONMENT_VARIABLE_5", "TRUE")

    actual_value = Variables.get_boolean_environment_variable(variable_name)

    assert actual_value == true
  end

  test "Scenario: Getting un-trimmed int environment variable" do
    variable_name = given_environment_variable("TEST_ENVIRONMENT_VARIABLE_6", "1234")

    actual_value = Variables.get_int_environment_variable(variable_name)

    assert actual_value == 1234
  end

  test "Scenario: Getting un-trimmed float environment variable" do
    variable_name = given_environment_variable("TEST_ENVIRONMENT_VARIABLE_7", "1234.5678")

    actual_value = Variables.get_float_environment_variable(variable_name)

    assert actual_value == 1234.5678
  end

  test "Scenario: Getting JSON string environment variable" do
    variable_name =
      given_environment_variable(
        "TEST_ENVIRONMENT_VARIABLE_8",
        ~s({ "name": "John", "age": 30, "city": "New York"})
      )

    actual_value = Variables.get_json_environment_variable(variable_name)

    assert actual_value == %{"age" => 30, "city" => "New York", "name" => "John"}
  end
end
