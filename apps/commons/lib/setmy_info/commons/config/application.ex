defmodule SetmyInfo.Commons.Config.Application do
    @moduledoc """
    Spring Boot style layered application configuration. Port of
    `info.setmy.config.application` (clj-commons) /
    `smi_python_commons.config.application` (python-commons), keeping their
    function names, their step order and their intermediate results, and
    completing the overload order the architecture index documents.

    ## Overload order

    Every layer below overrides the one above it:

    | Layer                                       | Selected by                                  |
    |---------------------------------------------|----------------------------------------------|
    | `application.{json,yml,yaml}`               | `config_paths`, in order                     |
    | `application-<profile>.{json,yml,yaml}`     | active profiles, in order                    |
    | optional files from `SMI_OPTIONAL_CONFIG_FILES` | environment                              |
    | optional files from `--smi-optional-config-files` | CLI                                    |
    | `${ENV_VAR}` placeholders inside those files| resolved as each file is read                |
    | environment variables (`SMI_...`)           | `SetmyInfo.Commons.Config.Overrides`         |
    | CLI options (`--smi-...`)                   | `SetmyInfo.Commons.Config.Overrides`         |

    Files merge deeply (python-commons' `merge_dicts`; clj-commons merges only
    the top level, which loses sibling keys and is not reproduced here).

    ## Profiles

    `local` is active by default - ADR-0041 makes it the canonical
    developer-machine environment and ADR-0042 binds profile names to it
    one-to-one. `SMI_PROFILES` replaces that list, `--smi-profiles` replaces
    it again; the layers replace rather than accumulate, matching both older
    rows' `find-last-not-none-and-empty`.

    ## Usage

        args_config =
          Config.new("my-service", [
            Argument.new("input", "i", &Function.identity/1, "Input file", true)
            | Constants.smi_arguments()
          ])

        app = Application.init(System.argv(), args_config)
        Application.get(app, ["smi", "server", "port"], 8080)
    """

    require Logger

    alias SetmyInfo.Commons.Arguments.Config, as: ArgumentsConfig
    alias SetmyInfo.Commons.Arguments.Constants, as: ArgumentsConstants
    alias SetmyInfo.Commons.Arguments.Parser, as: ArgumentsParser
    alias SetmyInfo.Commons.Collection.Operations, as: CollectionOperations
    alias SetmyInfo.Commons.Config.Constants
    alias SetmyInfo.Commons.Config.Overrides
    alias SetmyInfo.Commons.Environment.Variables
    alias SetmyInfo.Commons.Json.Parser, as: JsonParser
    alias SetmyInfo.Commons.String.Operations, as: StringOperations
    alias SetmyInfo.Commons.Yaml.Parser, as: YamlParser

    @yaml_file_pattern ~r/\.(yaml|yml)$/
    @json_file_pattern ~r/\.json$/

    defstruct arguments: nil,
              env_profiles: [],
              cli_profiles: [],
              env_config_paths: [],
              cli_config_paths: [],
              config_paths: [],
              profiles_list: [],
              default_application_files: [],
              application_profiles_file_prefixes: [],
              application_profiles_files: [],
              application_files: [],
              applications_files_contents: [],
              file_configuration: %{},
              environment_overrides: %{},
              cli_overrides: %{},
              merged_configuration: %{},
              name: "default"

    @type t :: %__MODULE__{}

    @doc """
    Loads the configuration. `opts` accepts `:config_paths`,
    `:default_profiles` and `:override_root_keys`, each replacing the
    corresponding `SetmyInfo.Commons.Config.Constants` default.
    """
    @spec init([String.t()], ArgumentsConfig.t() | nil, keyword()) :: t()
    def init(args \\ System.argv(), args_config \\ nil, opts \\ [])

    def init(args, nil, opts), do: init(args, ArgumentsConstants.smi_config(), opts)

    def init(args, %ArgumentsConfig{} = args_config, opts) do
        arguments = ArgumentsParser.parse_arguments(args, args_config)

        paths = resolve_paths(arguments, opts)
        profiles = resolve_profiles(arguments, opts)
        files = resolve_application_files(profiles.profiles_list)

        applications_files_contents =
            applications_files_paths_parsing(
                paths.config_paths,
                files.application_files,
                Variables.get_environment_variables_list(Constants.smi_optional_config_files()),
                cli_list_option(arguments, :smi_optional_config_files)
            )

        file_configuration = merge_config(applications_files_contents)
        overridden = apply_override_layers(file_configuration, args, opts)

        %__MODULE__{
            arguments: %{arguments | errors: remaining_errors(arguments, overridden)},
            env_config_paths: paths.env_config_paths,
            cli_config_paths: paths.cli_config_paths,
            config_paths: paths.config_paths,
            env_profiles: profiles.env_profiles,
            cli_profiles: profiles.cli_profiles,
            profiles_list: profiles.profiles_list,
            default_application_files: files.default_application_files,
            application_profiles_file_prefixes: files.application_profiles_file_prefixes,
            application_profiles_files: files.application_profiles_files,
            application_files: files.application_files,
            applications_files_contents: applications_files_contents,
            file_configuration: file_configuration,
            environment_overrides: overridden.environment_overrides,
            cli_overrides: overridden.cli_overrides,
            merged_configuration: overridden.merged_configuration,
            name: resolve_name(arguments, overridden.merged_configuration)
        }
    end

    @doc """
    Reads a value out of the merged configuration by path. Returns `default`
    when the path is absent, when a value on the way is not a map (a malformed
    file can turn a subtree into a scalar - see `merge_config/1`), and when
    the leaf is an explicit YAML `null`; `null` and "missing" are deliberately
    indistinguishable here, matching both older rows.
    """
    @spec get(t(), [String.t()], term()) :: term()
    def get(%__MODULE__{merged_configuration: configuration}, path, default \\ nil) do
        case dig(configuration, path) do
            nil -> default
            value -> value
        end
    end

    # `get_in/2` raises on a scalar in the middle of the path; this walk
    # treats it as "not there", which is what a config lookup means by it.
    defp dig(value, []), do: value
    defp dig(map, [key | rest]) when is_map(map), do: dig(Map.get(map, key), rest)
    defp dig(_non_map, _path), do: nil

    @doc """
    The last argument that is a non-empty list, or `[]`. Port of
    clj-commons' `find-last-not-none-and-empty` / python-commons'
    `find_last_not_none_and_empty`; variadic there, one list here.
    """
    @spec find_last_not_none_and_empty([term()]) :: list()
    def find_last_not_none_and_empty(values) do
        Enum.reduce(values, [], fn value, acc ->
            if is_list(value) and value != [], do: value, else: acc
        end)
    end

    @doc "Deep merge, right side winning. python-commons' `merge_dicts`."
    @spec merge_maps(term(), term()) :: term()
    def merge_maps(left, right) when is_map(left) and is_map(right) do
        Map.merge(left, right, fn _key, left_value, right_value ->
            merge_maps(left_value, right_value)
        end)
    end

    def merge_maps(left, nil), do: left
    def merge_maps(_left, right), do: right

    @doc """
    Folds the `{path, parsed}` pairs into one configuration map, in load order.

    Only maps take part: YAML's leniency lets accidental garbage parse
    "successfully" as one scalar string, and (right side winning) a bare
    `merge_maps/2` would then replace everything loaded before it. A file that
    exists but parsed to `nil` or to a non-map is logged and skipped - a
    silently vanishing config file is the worst kind of miss.
    """
    @spec merge_config([{Path.t(), term()}]) :: map()
    def merge_config(applications_files_contents) do
        Enum.reduce(applications_files_contents, %{}, fn
            {_path, parsed}, acc when is_map(parsed) ->
                merge_maps(acc, parsed)

            {path, nil}, acc ->
                if File.regular?(path),
                    do: Logger.warning("Config file #{path} could not be parsed - ignored")

                acc

            {path, parsed}, acc ->
                Logger.warning(
                    "Config file #{path} does not contain a map at the top level " <>
                        "(got: #{inspect(parsed)}) - ignored"
                )

                acc
        end)
    end

    @doc """
    Replaces `${NAME}` placeholders with environment variable values before
    the file is parsed. An unset variable leaves the placeholder untouched -
    both older rows do the same, and it makes the miss visible in the parsed
    configuration instead of turning into an empty string.
    """
    @spec post_read_function(String.t()) :: String.t()
    def post_read_function(text) do
        text
        |> StringOperations.find_named_placeholders()
        |> Enum.reduce(text, fn placeholder, acc ->
            case Variables.get_environment_variable(placeholder) do
                nil -> acc
                value -> StringOperations.replace_named_placeholder(acc, placeholder, value)
            end
        end)
    end

    @doc "Dispatches on file extension; an unknown extension parses to `nil`."
    @spec parse_file_by_type(Path.t()) :: term() | nil
    def parse_file_by_type(file_name) do
        post_actions = %{post_read_function: &post_read_function/1}
        lower_case_name = String.downcase(file_name)

        cond do
            Regex.match?(@yaml_file_pattern, lower_case_name) ->
                YamlParser.parse_yaml_file(file_name, post_actions)

            Regex.match?(@json_file_pattern, lower_case_name) ->
                JsonParser.parse_json_file(file_name, post_actions)

            true ->
                nil
        end
    end

    @doc "`{path, parsed}` for every config file that exists, in overload order."
    @spec applications_files_paths_parsing([String.t()], [String.t()], [String.t()], [String.t()]) ::
            [{Path.t(), term()}]
    def applications_files_paths_parsing(
          config_paths,
          application_files,
          optional_env_application_files,
          optional_cli_application_files
        ) do
        config_paths
        |> StringOperations.combined_by_function_list(application_files, "/", &File.regular?/1)
        |> Enum.concat(optional_env_application_files)
        |> Enum.concat(optional_cli_application_files)
        |> Enum.map(fn item -> {item, parse_file_by_type(item)} end)
    end

    @doc "`application.name` out of a merged configuration map, or `nil`."
    @spec get_config_app_name(map()) :: String.t() | nil
    def get_config_app_name(config) do
        case Map.get(config, "application") do
            application when is_map(application) -> Map.get(application, "name")
            _other -> nil
        end
    end

    defp resolve_paths(arguments, opts) do
        env_config_paths = Variables.get_environment_variables_list(Constants.smi_config_paths())
        cli_config_paths = cli_list_option(arguments, :smi_config_paths)

        %{
            env_config_paths: env_config_paths,
            cli_config_paths: cli_config_paths,
            config_paths:
                CollectionOperations.apply_concat_many([
                    Keyword.get(opts, :config_paths, Constants.default_config_paths()),
                    env_config_paths,
                    cli_config_paths
                ])
        }
    end

    defp resolve_profiles(arguments, opts) do
        env_profiles = Variables.get_environment_variables_list(Constants.smi_profiles())
        cli_profiles = cli_list_option(arguments, :smi_profiles)

        %{
            env_profiles: env_profiles,
            cli_profiles: cli_profiles,
            profiles_list:
                find_last_not_none_and_empty([
                    Keyword.get(opts, :default_profiles, Constants.default_profiles()),
                    env_profiles,
                    cli_profiles
                ])
        }
    end

    defp resolve_application_files(profiles_list) do
        prefixes = Constants.application_file_prefixes()
        suffixes = Constants.application_file_suffixes()

        default_application_files = StringOperations.combined_list(prefixes, suffixes, ".")
        profile_prefixes = StringOperations.combined_list(prefixes, profiles_list, "-")
        profile_files = StringOperations.combined_list(profile_prefixes, suffixes, ".")

        %{
            default_application_files: default_application_files,
            application_profiles_file_prefixes: profile_prefixes,
            application_profiles_files: profile_files,
            application_files: default_application_files ++ profile_files
        }
    end

    defp apply_override_layers(file_configuration, args, opts) do
        root_keys = Keyword.get(opts, :override_root_keys, Constants.default_override_root_keys())

        environment_overrides = Overrides.environment_overrides(file_configuration, root_keys)
        with_environment = Overrides.apply_overrides(file_configuration, environment_overrides)

        cli_overrides = Overrides.cli_overrides(with_environment, args, root_keys)

        %{
            root_keys: root_keys,
            environment_overrides: environment_overrides,
            cli_overrides: cli_overrides,
            merged_configuration: Overrides.apply_overrides(with_environment, cli_overrides)
        }
    end

    # An override flag such as `--smi-server-port` is not in the declared
    # option set, so OptionParser reports it as unknown. It only becomes
    # recognisable once the YAML has been read, which is here.
    defp remaining_errors(arguments, overridden) do
        known =
            Overrides.all_cli_option_names(overridden.merged_configuration, overridden.root_keys)

        Enum.reject(arguments.errors, fn
            {:unknown_option, flag} -> flag in known
            _other -> false
        end)
    end

    defp resolve_name(arguments, merged_configuration) do
        Map.get(arguments.options, :smi_name) ||
            Variables.get_environment_variable(Constants.smi_name()) ||
            get_config_app_name(merged_configuration) ||
            "default"
    end

    defp cli_list_option(arguments, key), do: Map.get(arguments.options, key) || []
end
