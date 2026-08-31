defmodule SetmyInfo.Commons.Config.Constants do
    @moduledoc """
    Configuration constants. Port of `info.setmy.config.constants` (clj-commons)
    / `smi_python_commons.config.constants` (python-commons), plus the three
    constants this row adds (`default_profiles/0`, `default_config_paths/0`,
    `default_override_root_keys/0`).
    """

    @smi_config_paths "SMI_CONFIG_PATHS"
    @smi_profiles "SMI_PROFILES"
    @smi_optional_config_files "SMI_OPTIONAL_CONFIG_FILES"
    @smi_name "SMI_NAME"

    @application_file_prefix "application"
    @application_file_suffixes ["json", "yml", "yaml"]

    @default_profiles ["local"]
    @default_config_paths ["./resources", "./test/resources"]
    @default_override_root_keys ["smi"]

    @doc "Environment variable naming the comma separated config directories: `SMI_CONFIG_PATHS`."
    @spec smi_config_paths() :: String.t()
    def smi_config_paths, do: @smi_config_paths

    @doc "Environment variable naming the comma separated active profiles: `SMI_PROFILES`."
    @spec smi_profiles() :: String.t()
    def smi_profiles, do: @smi_profiles

    @doc "Environment variable naming extra, comma separated config files: `SMI_OPTIONAL_CONFIG_FILES`."
    @spec smi_optional_config_files() :: String.t()
    def smi_optional_config_files, do: @smi_optional_config_files

    @doc "Environment variable carrying the application name: `SMI_NAME`."
    @spec smi_name() :: String.t()
    def smi_name, do: @smi_name

    @doc """
    The four control variables above never act as value overrides. Without
    this, an `smi.profiles` key in someone's YAML would silently pick up
    `SMI_PROFILES`, which selects *which files load* rather than carrying a
    value.
    """
    @spec reserved_environment_variables() :: [String.t()]
    def reserved_environment_variables do
        [@smi_config_paths, @smi_profiles, @smi_optional_config_files, @smi_name]
    end

    @doc "Base name of the configuration files: `application` (as in `application.yml`)."
    @spec application_file_prefix() :: String.t()
    def application_file_prefix, do: @application_file_prefix

    @doc "`application_file_prefix/0` as a one-element list, for the file discovery's cartesian products."
    @spec application_file_prefixes() :: [String.t()]
    def application_file_prefixes, do: [@application_file_prefix]

    @doc "In overloading order - a later suffix overrides an earlier one from the same directory."
    @spec application_file_suffixes() :: [String.t()]
    def application_file_suffixes, do: @application_file_suffixes

    @doc """
    `local` is active unless `SMI_PROFILES` or `--smi-profiles` says otherwise.

    ADR-0041 makes `local` a first-class canonical environment ("developer
    local machine") and ADR-0042 makes profile names one-to-one with it, so
    the developer-machine default is the only one that can be right without
    being told. Both older rows default to *no* profile instead - the one
    behavioural divergence in this port, and a deliberate one.
    """
    @spec default_profiles() :: [String.t()]
    def default_profiles, do: @default_profiles

    @doc """
    Later path wins. `./resources` is this repo's own source-resources
    convention, `./test/resources` mirrors both
    older rows' test-resources entry and lets a test run override it.
    """
    @spec default_config_paths() :: [String.t()]
    def default_config_paths, do: @default_config_paths

    @doc """
    Only keys under these roots can be overridden by environment variables or
    CLI options, per the architecture index's prefix table (`smi:` in YAML,
    `SMI_` in the environment, `--smi-` on the command line).

    `nil` means every root key, which is how Spring Boot behaves - and is
    unsafe by default here, since a top-level `name:` key would then bind to
    whatever `$NAME` happens to be in the shell.
    """
    @spec default_override_root_keys() :: [String.t()]
    def default_override_root_keys, do: @default_override_root_keys
end
