defmodule SetmyInfo.Commons.Arguments.Argument do
    @moduledoc """
    One CLI option declaration. Elixir struct equivalent of clj-commons'
    `ArgumentConfig` record / python-commons' `Argument` class, same five
    fields in the same order.

    `argument_type` is a 1-arity function applied to the raw string the parser
    captured (`&String.Operations.split_and_trim/1`, `&Function.identity/1`,
    ...), matching both originals' `argument-type-func` / `argument_type`.
    """

    alias SetmyInfo.Commons.String.Operations, as: StringOperations

    @enforce_keys [:name, :short_flag]
    defstruct [:name, :short_flag, :argument_type, argument_help: "", required: false]

    @type t :: %__MODULE__{
            name: String.t(),
            short_flag: String.t() | nil,
            argument_type: (String.t() -> term()) | nil,
            argument_help: String.t(),
            required: boolean()
          }

    @doc """
    Builds an option declaration. `name` is the long flag without the leading
    `--` (`"smi-profiles"`), `short_flag` the single-letter alias or `nil`,
    `argument_type` the optional cast function applied to the captured value,
    `argument_help` the summary text and `required` whether a missing option
    is reported as an error by the parser.
    """
    @spec new(String.t(), String.t() | nil, (String.t() -> term()) | nil, String.t(), boolean()) ::
            t()
    def new(name, short_flag, argument_type \\ nil, argument_help \\ "", required \\ false) do
        %__MODULE__{
            name: name,
            short_flag: short_flag,
            argument_type: argument_type,
            argument_help: argument_help,
            required: required
        }
    end

    @doc """
    The `OptionParser` key this option parses into: `"smi-config-paths"` ->
    `:smi_config_paths`, matching `OptionParser`'s own dash-to-underscore
    conversion and python-commons' `argparse` namespace attribute names.
    """
    @spec option_key(t()) :: atom()
    def option_key(%__MODULE__{name: name}) do
        name |> String.replace("-", "_") |> String.to_atom()
    end

    @doc "The long flag as it appears on the command line, e.g. `--smi-profiles`."
    @spec long_flag(t()) :: String.t()
    def long_flag(%__MODULE__{name: name}), do: "--" <> name

    @doc "Applies the declared `argument_type` function; a missing one leaves the raw string."
    @spec cast(t(), String.t()) :: term()
    def cast(%__MODULE__{argument_type: nil}, value), do: value
    def cast(%__MODULE__{argument_type: argument_type}, value), do: argument_type.(value)

    @doc "Help line for `SetmyInfo.Commons.Arguments.Parser`'s generated summary."
    @spec summary_line(t()) :: String.t()
    def summary_line(%__MODULE__{} = argument) do
        flags =
            case argument.short_flag do
                nil -> "    " <> long_flag(argument)
                short_flag -> "-" <> short_flag <> ", " <> long_flag(argument)
            end

        "  " <> flags <> "  " <> StringOperations.nil_to_default(argument.argument_help)
    end
end
