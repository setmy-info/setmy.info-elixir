defmodule SetmyInfo.Commons.Json.Parser do
    @moduledoc """
    JSON file parsing, with the same `post_read_function` /
    `post_parse_function` hook pair as `SetmyInfo.Commons.Yaml.Parser`. Port of
    `info.setmy.json.parser` (clj-commons) / `smi_python_commons.json.parser`
    (python-commons).

    Uses the stdlib `JSON` module (Elixir 1.18+ / OTP 27+ `:json`) rather than
    adding a Jason dependency.

    ## Failure, and where it differs from the YAML parser

    Both file parsers return `nil` for content they cannot parse, but they do
    NOT agree on a **missing** file. `SetmyInfo.Commons.File.Operations` reads
    one as `""`, and the two parsers disagree about what `""` means:

    | Input                  | `parse_json_file/2` | `Yaml.Parser.parse_yaml_file/2` |
    |------------------------|---------------------|---------------------------------|
    | missing file (`""`)    | `nil`               | `%{}`                           |
    | syntactically invalid  | `nil`               | `nil`                           |

    `""` is simply not a JSON document, while YAML reads it as an empty one.
    Callers that must tell "absent" from "broken" apart should check
    `File.regular?/1` first; `SetmyInfo.Commons.Config.Application.merge_config/1`
    does exactly that before warning about a file it could not use.

    Note also that the *file* parsers report failure as `nil`, while the
    *string* parsers in `SetmyInfo.Commons.String.Operations`
    (`json_to_object/2`, `yaml_to_object/2`) return their `default_value`
    (`%{}` unless given) instead. That split is deliberate - a caller handed a
    path can act on "there was nothing usable here", a caller handed a string
    normally just wants a map - and it is the behaviour of both older rows.
    """

    alias SetmyInfo.Commons.File.Operations, as: FileOperations

    @doc """
    Reads and decodes a JSON file. `post_actions` may carry
    `:post_read_function` (applied to the raw text before decoding) and
    `:post_parse_function` (applied to the decoded value); both default to
    identity, and `nil` is accepted in place of the map. Returns the decoded
    (and post-processed) value, or `nil` when the content is not valid JSON -
    which includes the `""` a missing file reads as.
    """
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
