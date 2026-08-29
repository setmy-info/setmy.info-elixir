defmodule SetmyInfo.Commons.Environment.Variables do
  @moduledoc """
  Environment variable access. Port of `info.setmy.environment.variables`
  (clj-commons) / `smi_python_commons.environment.variables`
  (python-commons).

  `set_environment_variable/2` and `delete_environment_variable/1` follow the
  Python port and really do mutate the environment; the Clojure port raises
  `UnsupportedOperationException` for both, because the JVM has no supported
  way to write back into `System/getenv`. The BEAM does
  (`System.put_env/2`), and the integration tests need it the same way the
  Python ones do.
  """

  alias SetmyInfo.Commons.String.Operations, as: StringOperations

  @doc "Sets `variable_name` to `variable_value` in the current OS process environment."
  @spec set_environment_variable(String.t(), String.t()) :: :ok
  def set_environment_variable(variable_name, variable_value) do
    System.put_env(variable_name, variable_value)
  end

  @doc "Removes `variable_name` from the current OS process environment; a no-op if it is unset."
  @spec delete_environment_variable(String.t()) :: :ok
  def delete_environment_variable(variable_name), do: System.delete_env(variable_name)

  @doc "Raw value of `variable_name`, or `nil` when it is not set."
  @spec get_environment_variable(String.t()) :: String.t() | nil
  def get_environment_variable(variable_name), do: System.get_env(variable_name)

  @doc """
  Reads `variable_name` through `StringOperations.to_boolean/2`: `false`
  when unset, raises on a value that is not `true`/`yes`/`false`/`no`.
  """
  @spec get_boolean_environment_variable(String.t()) :: boolean()
  def get_boolean_environment_variable(variable_name) do
    StringOperations.to_boolean(get_environment_variable(variable_name))
  end

  @doc "Reads `variable_name` through `StringOperations.to_int/2`: `0` when unset or not a whole integer."
  @spec get_int_environment_variable(String.t()) :: number()
  def get_int_environment_variable(variable_name) do
    StringOperations.to_int(get_environment_variable(variable_name))
  end

  @doc "Reads `variable_name` through `StringOperations.to_float/2`: `0.0` when unset or not a float."
  @spec get_float_environment_variable(String.t()) :: number()
  def get_float_environment_variable(variable_name) do
    StringOperations.to_float(get_environment_variable(variable_name))
  end

  @doc "Reads `variable_name` through `StringOperations.json_to_object/2`: `%{}` when unset or invalid JSON."
  @spec get_json_environment_variable(String.t()) :: term()
  def get_json_environment_variable(variable_name) do
    StringOperations.json_to_object(get_environment_variable(variable_name))
  end

  @doc """
  Reads a comma separated environment variable as a trimmed list, dropping
  empty fragments (the Clojure original's `remove empty?`; the Python port
  keeps them, so `SMI_PROFILES=""` yields `[""]` there and `[]` here).

  `parse_function` is optional. The two originals disagree on its shape -
  Clojure's `map-indexed` calls it `(index, value)`, Python's comprehension
  calls it `(value, index)` - so both arities are accepted here: a 1-arity
  function gets the value, a 2-arity one gets `(value, index)`.
  """
  @spec get_environment_variables_list(String.t() | nil, function() | nil) :: [term()]
  def get_environment_variables_list(variable_name, parse_function \\ nil)
  def get_environment_variables_list(nil, _parse_function), do: []

  def get_environment_variables_list(variable_name, parse_function) do
    case get_environment_variable(variable_name) do
      nil ->
        []

      value ->
        value
        |> StringOperations.split_and_trim()
        |> Enum.reject(&(&1 == StringOperations.empty_string()))
        |> apply_parse_function(parse_function)
    end
  end

  defp apply_parse_function(list, nil), do: list

  defp apply_parse_function(list, parse_function) when is_function(parse_function, 1) do
    Enum.map(list, parse_function)
  end

  defp apply_parse_function(list, parse_function) when is_function(parse_function, 2) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {value, index} -> parse_function.(value, index) end)
  end
end
