defmodule SetmyInfo.Commons.Config.Overrides do
    @moduledoc """
    The two override layers the architecture index's "Application configuration"
    table puts *above* the config files - environment variables, then CLI
    options.

    Neither clj-commons nor python-commons implements this layer: both stop at
    `${ENV_VAR}` placeholder substitution inside the YAML text plus the four
    `SMI_*` control variables. This module is the Elixir row's addition, and
    the reason the full documented overload order

        defaults in code -> file (yaml over properties) -> environment -> CLI

    actually holds here.

    ## Which keys can be overridden

    Only *existing leaf paths* under an allowed root key, so an override can
    change a configured value but never invent one. Two consequences worth
    knowing before reaching for it:

    * A key absent from every loaded YAML file is not overridable. Declare it
      in `application.yaml` with a default and override that. This is the
      "if those exist" rule, and it is what makes the mapping unambiguous -
      `SMI_A_B_C` binds to whichever of `smi.a.b.c` / `smi.a.bC` / `smi.aB.c`
      actually exists, rather than guessing where the word boundaries were.
    * `root_keys` defaults to `["smi"]` (the index's prefix table). Passing
      `nil` allows every root key, Spring Boot style - convenient, and unsafe
      on a machine where `$NAME` or `$HOME` might collide with a top-level
      config key.

    ## Name derivation

    Each path yields two candidate names, tried in order, so both the
    underscore-per-word and Spring Boot's own run-the-word-together form work:

        ["smi", "server", "port"]  -> SMI_SERVER_PORT   --smi-server-port
        ["smi", "apiBaseUrl"]      -> SMI_API_BASE_URL  --smi-api-base-url
                                      SMI_APIBASEURL    --smi-apibaseurl

    ## Types

    The override string is coerced to the type of the value it replaces, so a
    YAML `port: 8080` stays an integer and `secure: false` stays a boolean.
    A list-valued key splits on commas. Anything else stays a string. A value
    that cannot be cast raises `ArgumentError` naming the variable or flag and
    the path - one policy for every type, because a typo'd override silently
    ignored (or crashing namelessly) is how services run on the wrong port.

    Two edges worth knowing: the underscore inside a key and the path
    separator collapse to the same character, so `smi.a_b` and `smi.a.b` both
    answer to `SMI_A_B` - when both exist, one variable overrides both keys;
    and an empty-map leaf (`feature: {}`) is overridable, taking the string
    branch of the coercion.
    """

    alias SetmyInfo.Commons.Arguments.Parser, as: ArgumentsParser
    alias SetmyInfo.Commons.Config.Constants
    alias SetmyInfo.Commons.Environment.Variables
    alias SetmyInfo.Commons.String.Operations, as: StringOperations

    @type path :: [String.t()]

    @doc "Every path to a non-map leaf, restricted to `root_keys` (`nil` = all roots)."
    @spec leaf_paths(map(), [String.t()] | nil) :: [path()]
    def leaf_paths(config, root_keys \\ nil) when is_map(config) do
        config
        |> Enum.filter(fn {key, _value} -> is_nil(root_keys) or to_string(key) in root_keys end)
        |> Enum.flat_map(fn {key, value} -> paths_of(to_string(key), value) end)
    end

    @doc "Candidate environment variable names for a config path, most specific first."
    @spec environment_variable_names(path()) :: [String.t()]
    def environment_variable_names(path) do
        path
        |> name_variants("_")
        |> Enum.map(&String.upcase/1)
        |> Enum.uniq()
    end

    @doc "Candidate CLI long flags for a config path, most specific first."
    @spec cli_option_names(path()) :: [String.t()]
    def cli_option_names(path) do
        path
        |> name_variants("-")
        |> Enum.map(&("--" <> String.downcase(&1)))
        |> Enum.uniq()
    end

    @doc "Every CLI flag that could override something in `config` - used to keep real override flags out of the parser's unknown-option errors."
    @spec all_cli_option_names(map(), [String.t()] | nil) :: [String.t()]
    def all_cli_option_names(config, root_keys \\ nil) do
        config |> leaf_paths(root_keys) |> Enum.flat_map(&cli_option_names/1) |> Enum.uniq()
    end

    @doc """
    `%{path => coerced_value}` for every leaf whose environment variable is
    set. Control variables (`SMI_PROFILES` and friends) are never consumed as
    value overrides.
    """
    @spec environment_overrides(map(), [String.t()] | nil) :: %{path() => term()}
    def environment_overrides(config, root_keys \\ nil) do
        reserved = Constants.reserved_environment_variables()

        collect(
            config,
            root_keys,
            fn path ->
                path |> environment_variable_names() |> Enum.reject(&(&1 in reserved))
            end,
            &Variables.get_environment_variable/1
        )
    end

    @doc """
    `%{path => coerced_value}` for every leaf whose CLI flag appears in
    `argv`. The control flags (`--smi-profiles` and friends) are never
    consumed as value overrides - the same guard `environment_overrides/2`
    applies to `SMI_PROFILES`, on this layer.
    """
    @spec cli_overrides(map(), [String.t()], [String.t()] | nil) :: %{path() => term()}
    def cli_overrides(config, argv, root_keys \\ nil) do
        reserved = Constants.reserved_cli_options()

        collect(
            config,
            root_keys,
            fn path -> path |> cli_option_names() |> Enum.reject(&(&1 in reserved)) end,
            &ArgumentsParser.find_option_value(argv, &1)
        )
    end

    @doc "Writes collected overrides back into the configuration map."
    @spec apply_overrides(map(), %{path() => term()}) :: map()
    def apply_overrides(config, overrides) do
        Enum.reduce(overrides, config, fn {path, value}, acc -> put_in(acc, path, value) end)
    end

    @doc """
    `collect/4` with an arbitrary lookup - the seam the unit tests use to
    exercise override resolution without touching the real environment.
    `names_builder` maps a config path to its candidate names, `lookup` maps a
    candidate name to a raw string or `nil`.
    """
    @spec collect(map(), [String.t()] | nil, (path() -> [String.t()]), (String.t() ->
                                                                          String.t() | nil)) ::
            %{path() => term()}
    def collect(config, root_keys, names_builder, lookup) do
        config
        |> leaf_paths(root_keys)
        |> Enum.reduce(%{}, fn path, acc ->
            case first_present(names_builder.(path), lookup) do
                nil -> acc
                {name, raw} -> Map.put(acc, path, coerce_like(get_in(config, path), raw, name, path))
            end
        end)
    end

    defp first_present(names, lookup) do
        Enum.find_value(names, fn name ->
            case lookup.(name) do
                nil -> nil
                raw -> {name, raw}
            end
        end)
    end

    defp paths_of(key, value) when is_map(value) and map_size(value) > 0 do
        Enum.flat_map(value, fn {child_key, child_value} ->
            Enum.map(paths_of(to_string(child_key), child_value), &[key | &1])
        end)
    end

    defp paths_of(key, _value), do: [[key]]

    # Two variants per path: every word split out ("apiBaseUrl" -> API_BASE_URL)
    # and every word run together (-> APIBASEURL, Spring Boot's own form).
    defp name_variants(path, joiner) do
        [
            join_variant(path, &snake_segment/1, joiner),
            join_variant(path, &flat_segment/1, joiner)
        ]
    end

    defp join_variant(path, segment_function, joiner) do
        path |> Enum.map_join("_", segment_function) |> String.replace("_", joiner)
    end

    defp snake_segment(segment) do
        segment |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1_\\2") |> flat_segment()
    end

    defp flat_segment(segment), do: String.replace(segment, ~r/[^A-Za-z0-9]+/, "_")

    # One failure policy for every type: reject loudly, naming the source.
    # (`StringOperations.to_int/2` and friends fall back to a default instead,
    # which is right for reading a lone value and wrong here - an override
    # that silently keeps the old value hides the typo that broke it.)
    defp coerce_like(current, raw, name, path) when is_boolean(current) do
        case String.downcase(raw) do
            value when value in ["true", "yes"] -> true
            value when value in ["false", "no"] -> false
            _other -> reject(name, path, raw, "a boolean (true/yes/false/no)")
        end
    end

    defp coerce_like(current, raw, name, path) when is_integer(current) do
        case Integer.parse(raw) do
            {value, ""} -> value
            _other -> reject(name, path, raw, "an integer")
        end
    end

    defp coerce_like(current, raw, name, path) when is_float(current) do
        case Float.parse(raw) do
            {value, ""} -> value
            _other -> reject(name, path, raw, "a float")
        end
    end

    defp coerce_like(current, raw, _name, _path) when is_list(current),
        do: StringOperations.split_and_trim(raw)

    defp coerce_like(_current, raw, _name, _path), do: raw

    @spec reject(String.t(), path(), String.t(), String.t()) :: no_return()
    defp reject(name, path, raw, wanted) do
        raise ArgumentError,
              "override #{name} for #{Enum.join(path, ".")} is #{inspect(raw)}, not #{wanted}"
    end
end
