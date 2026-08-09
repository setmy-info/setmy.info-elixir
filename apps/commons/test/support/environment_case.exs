defmodule SetmyInfo.Commons.EnvironmentCase do
  @moduledoc """
  Shared setup for the tiers ADR-0031 lets touch the environment (IT, E2ET):
  clears the four `SMI_*` control variables plus any override variable a
  test set, and restores whatever the surrounding shell had.

  Equivalent of python-commons' `IntegrationTestApplication.setUp`, which
  deletes `SMI_PROFILES`/`SMI_CONFIG_PATHS`/`SMI_OPTIONAL_CONFIG_FILES` and
  seeds the `SOME_*` placeholder values before every case. Restoring is
  added here because ExUnit runs every test module in one OS process, so a
  leaked variable would reach the next module.
  """

  use ExUnit.CaseTemplate

  alias SetmyInfo.Commons.Config.Constants

  @placeholder_variables %{
    "SOME_NUMBER_VALUE_A" => "123",
    "SOME_NUMBER_VALUE_B" => "123.456",
    "SOME_BOOLEAN_VALUE_A" => "true",
    "SOME_BOOLEAN_VALUE_B" => "false",
    "SOME_STRING_VALUE_A" => "A AA AAA",
    "SOME_STRING_VALUE_B" => "B BB BBB"
  }

  using do
    quote do
      import SetmyInfo.Commons.EnvironmentCase
    end
  end

  setup do
    original = System.get_env()

    Enum.each(Constants.reserved_environment_variables(), &System.delete_env/1)
    System.put_env(@placeholder_variables)

    on_exit(fn -> restore_environment(original) end)

    :ok
  end

  @doc "Every `${...}` placeholder value the shared `application.yaml` fixture references."
  def placeholder_variables, do: @placeholder_variables

  @doc "Sets environment variables for the duration of one test."
  def put_environment(variables) do
    System.put_env(variables)
    :ok
  end

  defp restore_environment(original) do
    Enum.each(System.get_env(), fn {key, _value} ->
      unless Map.has_key?(original, key), do: System.delete_env(key)
    end)

    System.put_env(original)
  end
end
