defmodule SetmyInfo.Commons.Yaml.Parser do
    @moduledoc """
    YAML file parsing with the same `post_read_function` / `post_parse_function`
    hook pair as `info.setmy.yaml.parser` (clj-commons) /
    `smi_python_commons.yaml.parser` (python-commons).

    `post_read_function` runs on the raw text *before* parsing - that ordering
    is what makes `${SOME_ENV_VAR}` substitution produce real YAML scalars
    (`d: ${SOME_NUMBER_VALUE_A}` with `SOME_NUMBER_VALUE_A=123` parses to the
    integer `123`, not the string `"123"`), exactly like Spring Boot's own
    property placeholder resolution.

    Keys come back as strings, matching the Python port. The Clojure port
    keywordizes them; on the BEAM that would mean `String.to_atom/1` on
    file-supplied input, i.e. an unbounded atom table.
    """

    alias SetmyInfo.Commons.File.Operations, as: FileOperations

    @type post_actions :: %{
            optional(:post_read_function) => (String.t() -> String.t()),
            optional(:post_parse_function) => (term() -> term())
          }

    @doc """
    Reads and parses a YAML file. `post_actions` may carry
    `:post_read_function` (applied to the raw text before parsing) and
    `:post_parse_function` (applied to the parsed value); both default to
    identity, and `nil` is accepted in place of the map. Returns the parsed
    (and post-processed) value, or `nil` when the content is not valid YAML.
    A missing file reads as `""`, which parses to an empty document.
    """
    @spec parse_yaml_file(Path.t(), post_actions() | nil) :: term() | nil
    def parse_yaml_file(file_name, post_actions \\ %{}) do
        post_actions = post_actions || %{}
        post_read_function = Map.get(post_actions, :post_read_function, & &1)
        post_parse_function = Map.get(post_actions, :post_parse_function, & &1)

        parsed =
            file_name
            |> FileOperations.read_file()
            |> post_read_function.()
            |> YamlElixir.read_from_string()

        case parsed do
            {:ok, content} -> post_parse_function.(content)
            {:error, _reason} -> nil
        end
    end
end
