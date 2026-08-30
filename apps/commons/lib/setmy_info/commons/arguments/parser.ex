defmodule SetmyInfo.Commons.Arguments.Parser do
    @moduledoc """
    CLI parsing over `OptionParser`. Port of `info.setmy.arguments.parser`
    (clj-commons, `clojure.tools.cli`) / `smi_python_commons.arguments.parser`
    (python-commons, `argparse`).

    Two deliberate differences from the originals:

    * The full argument list is parsed, nothing is stripped. python-commons
      does `argv[1:]` because Python's `sys.argv[0]` is the script path;
      `System.argv/0` already excludes it, and clj-commons doesn't strip
      either.
    * A missing required option is *reported* (`{:missing_required, flag}`),
      not fatal. `argparse` prints usage and calls `sys.exit(2)` - unusable
      from a library, and untestable without trapping exits.
    * An *undeclared* option swallows the token after it.
      `["-i", "input.txt"]` with no `-i` declared yields
      `invalid: [{"-i", nil}]` and no positional `"input.txt"` at all;
      `clojure.tools.cli` reports the same unknown option but keeps
      `"input.txt"` in `:arguments`. This is `OptionParser`'s own behaviour,
      confirmed directly rather than assumed, and the only way around it
      would be hand-rolling a parser - not worth it for the undeclared-option
      path. Declared options are unaffected.
    """

    alias SetmyInfo.Commons.Arguments.{Argument, Config, ParsedArguments}

    @doc """
    Parses `args` (normally `System.argv/0`) against the options declared in
    `config`. Declared options are cast with their `argument_type` and keyed
    by `Argument.option_key/1` (last occurrence wins); remaining tokens are
    positional `arguments`; undeclared options and missing required ones are
    collected as `errors`; `summary` is the generated help text.
    """
    @spec parse_arguments([String.t()], Config.t()) :: ParsedArguments.t()
    def parse_arguments(args, %Config{arguments: arguments_config}) do
        {parsed, positional, invalid} =
            OptionParser.parse(args,
                strict: Enum.map(arguments_config, &{Argument.option_key(&1), :string}),
                aliases: build_aliases(arguments_config)
            )

        options = cast_options(parsed, arguments_config)

        %ParsedArguments{
            options: options,
            arguments: positional,
            errors:
                unknown_option_errors(invalid) ++ missing_required_errors(arguments_config, options),
            summary: summary(arguments_config)
        }
    end

    @doc """
    Raw scan for a single long option's value, independent of any declared
    option set: `--flag=value` or `--flag value`, last occurrence winning.

    `SetmyInfo.Commons.Config.Overrides` needs this because configuration
    override flags (`--smi-server-port`) are derived from the *loaded YAML*,
    so they cannot be in `OptionParser`'s strict switch list at parse time.
    """
    @spec find_option_value([String.t()], String.t()) :: String.t() | nil
    def find_option_value(argv, option_name) do
        argv
        |> Enum.with_index()
        |> Enum.reduce(nil, fn {token, index}, acc ->
            option_value_at(argv, token, index, option_name) || acc
        end)
    end

    @doc "Generated help text, one line per declared option."
    @spec summary([Argument.t()]) :: String.t()
    def summary(arguments_config) do
        Enum.map_join(arguments_config, "\n", &Argument.summary_line/1)
  end

    defp option_value_at(argv, token, index, option_name) do
        cond do
            token == option_name -> next_token_value(Enum.at(argv, index + 1))
            String.starts_with?(token, option_name <> "=") -> inline_value(token, option_name)
            true -> nil
        end
    end

    defp inline_value(token, option_name), do: String.replace_prefix(token, option_name <> "=", "")

    defp next_token_value(nil), do: nil
    defp next_token_value("--" <> _rest), do: nil
    defp next_token_value(value), do: value

    defp build_aliases(arguments_config) do
        arguments_config
        |> Enum.reject(&is_nil(&1.short_flag))
        |> Enum.map(&{String.to_atom(&1.short_flag), Argument.option_key(&1)})
    end

    # `parsed` is a keyword list, so a repeated option appears repeatedly;
    # Map.new keeps the last, which is the usual "last flag wins" CLI rule.
    defp cast_options(parsed, arguments_config) do
        by_key = Map.new(arguments_config, &{Argument.option_key(&1), &1})

        Map.new(parsed, fn {key, value} ->
            case Map.fetch(by_key, key) do
                {:ok, argument} -> {key, Argument.cast(argument, value)}
                :error -> {key, value}
            end
        end)
    end

    defp unknown_option_errors(invalid) do
        Enum.map(invalid, fn {flag, _value} -> {:unknown_option, flag} end)
    end

    defp missing_required_errors(arguments_config, options) do
        arguments_config
        |> Enum.filter(&(&1.required and not Map.has_key?(options, Argument.option_key(&1))))
        |> Enum.map(&{:missing_required, Argument.long_flag(&1)})
    end
end
