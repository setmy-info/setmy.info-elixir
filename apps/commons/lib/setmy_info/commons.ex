defmodule SetmyInfo.Commons do
    @moduledoc """
    setmy.info Elixir commons - Spring Boot style layered application
    configuration.

    The Elixir row of the same library `clj-commons` (`info.setmy.*`) and
    `python-commons` (`smi_python_commons.*`) already implement; module names,
    function names and argument order are kept one-to-one with those, with
    every deliberate difference documented in the module that carries it.

    ## Quick start

        # apps/my_app/resources/application.yaml
        # application:
        #   name: my-service
        # smi:
        #   server:
        #     port: 8080
        #   apiBaseUrl: ${API_BASE_URL}

        app = SetmyInfo.Commons.load()
        SetmyInfo.Commons.Config.Application.get(app, ["smi", "server", "port"])

    With `local` active by default, `application.yaml` loads first and
    `application-local.yaml` overrides it; `SMI_SERVER_PORT=9090` overrides
    both, and `--smi-server-port 9091` overrides all three.

    ## Modules

    | Module                                     | clj-commons / python-commons counterpart |
    |--------------------------------------------|------------------------------------------|
    | `SetmyInfo.Commons.Config.Application`     | `config.application`                     |
    | `SetmyInfo.Commons.Config.Constants`       | `config.constants`                       |
    | `SetmyInfo.Commons.Config.Overrides`       | *(new in this row)*                      |
    | `SetmyInfo.Commons.Arguments.Parser`       | `arguments.parser`                       |
    | `SetmyInfo.Commons.Arguments.Constants`    | `arguments.constants`                    |
    | `SetmyInfo.Commons.Arguments.Argument`     | `arguments.argument`                     |
    | `SetmyInfo.Commons.Arguments.Config`       | `arguments.config`                       |
    | `SetmyInfo.Commons.Arguments.ParsedArguments` | *(new in this row)*                   |
    | `SetmyInfo.Commons.Environment.Variables`  | `environment.variables`                  |
    | `SetmyInfo.Commons.Yaml.Parser`            | `yaml.parser`                            |
    | `SetmyInfo.Commons.Json.Parser`            | `json.parser`                            |
    | `SetmyInfo.Commons.String.Operations`      | `string.operations`                      |
    | `SetmyInfo.Commons.File.Operations`        | `file.operations`                        |
    | `SetmyInfo.Commons.Collection.Operations`  | `collection.operations`                  |
    """

    alias SetmyInfo.Commons.Arguments.Config, as: ArgumentsConfig
    alias SetmyInfo.Commons.Config.Application, as: ConfigApplication

    @doc """
    Loads the configuration from `System.argv/0` (or explicit `args`) using
    only the four `--smi-*` options. Applications with CLI options of their
    own should call `SetmyInfo.Commons.Config.Application.init/3` with their
    own `SetmyInfo.Commons.Arguments.Config`.
    """
    @spec load([String.t()], ArgumentsConfig.t() | nil, keyword()) :: ConfigApplication.t()
    def load(args \\ System.argv(), args_config \\ nil, opts \\ []) do
        ConfigApplication.init(args, args_config, opts)
    end
end
