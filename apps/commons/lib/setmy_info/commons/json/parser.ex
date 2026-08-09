defmodule SetmyInfo.Commons.Json.Parser do
  @moduledoc """
  JSON file parsing, same hook pair and same "nil on failure" contract as
  `SetmyInfo.Commons.Yaml.Parser`. Port of `info.setmy.json.parser`
  (clj-commons) / `smi_python_commons.json.parser` (python-commons).

  Uses the stdlib `JSON` module (Elixir 1.18+ / OTP 27+ `:json`) rather than
  adding a Jason dependency - the same choice `Mix.Tasks.Server` in
  `dev_tasks` already made for its own state file.
  """

  alias SetmyInfo.Commons.File.Operations, as: FileOperations

  @spec parse_json_file(Path.t(), map() | nil) :: term() | nil
  def parse_json_file(file_name, post_actions \\ %{}) do
    post_actions = post_actions || %{}
    post_read_function = Map.get(post_actions, :post_read_function, & &1)
    post_parse_function = Map.get(post_actions, :post_parse_function, & &1)

    parsed =
      file_name
      |> FileOperations.read_file()
      |> post_read_function.()
      |> JSON.decode()

    case parsed do
      {:ok, content} -> post_parse_function.(content)
      {:error, _reason} -> nil
    end
  end
end
