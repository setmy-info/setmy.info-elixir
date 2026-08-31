defmodule SetmyInfo.Commons.Arguments.Constants do
    @moduledoc """
    The four `--smi-*` CLI options from the architecture index's "Application
    configuration" table. Port of `info.setmy.arguments.constants` (clj-commons)
    / `smi_python_commons.arguments.constants` (python-commons).

    Functions rather than module attributes because each one closes over a
    function capture (`argument_type`), which cannot live in a module
    attribute.

    Short flag for `--smi-name` is `n`, following python-commons. clj-commons
    gives it `o`, colliding with its own `--smi-optional-config-files`.
    """

    alias SetmyInfo.Commons.Arguments.{Argument, Config}
    alias SetmyInfo.Commons.String.Operations, as: StringOperations

    @doc "`--smi-profiles` / `-p`: comma separated profile names, cast to a trimmed list."
    @spec smi_profiles_argument() :: Argument.t()
    def smi_profiles_argument do
        Argument.new(
            "smi-profiles",
            "p",
            &StringOperations.split_and_trim/1,
            "Comma separated profiles string (ADR-0041/0042: local, dev, ci, test, prelive, live)."
        )
    end

    @doc "`--smi-config-paths` / `-c`: comma separated config directories, cast to a trimmed list."
    @spec smi_config_paths_argument() :: Argument.t()
    def smi_config_paths_argument do
        Argument.new(
            "smi-config-paths",
            "c",
            &StringOperations.split_and_trim/1,
            "Comma separated config paths."
        )
    end

    @doc "`--smi-optional-config-files` / `-o`: comma separated config file paths, cast to a trimmed list."
    @spec smi_optional_config_files_argument() :: Argument.t()
    def smi_optional_config_files_argument do
        Argument.new(
            "smi-optional-config-files",
            "o",
            &StringOperations.split_and_trim/1,
            "Comma separated config files."
        )
    end

    @doc "`--smi-name` / `-n`: the application name, kept as the raw string."
    @spec smi_name_argument() :: Argument.t()
    def smi_name_argument do
        Argument.new("smi-name", "n", &Function.identity/1, "Application name.")
    end

    @doc "All four `--smi-*` declarations, in the order of the architecture index table."
    @spec smi_arguments() :: [Argument.t()]
    def smi_arguments do
        [
            smi_profiles_argument(),
            smi_config_paths_argument(),
            smi_optional_config_files_argument(),
            smi_name_argument()
        ]
    end

    @doc """
    A ready-made `Config` carrying only the four `--smi-*` options - the
    default for `SetmyInfo.Commons.Config.Application.init/3` when an
    application has no CLI options of its own.
    """
    @spec smi_config(String.t()) :: Config.t()
    def smi_config(description \\ "setmy.info application configuration options.") do
        Config.new(description, smi_arguments())
    end
end
