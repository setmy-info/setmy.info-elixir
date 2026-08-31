defmodule SetmyInfo.Commons.Config.LoadingE2eTest do
    @moduledoc """
    E2E tier (ADR-0031). Drives the whole library the way a real application
    does - `SetmyInfo.Commons.load/3` with a real argv, real files on disk and
    a real process environment - and asserts the complete overload order in
    one pass, rather than one layer at a time the way the integration tier
    does.
    """

    use SetmyInfo.Commons.EnvironmentCase, async: false

    @moduletag :e2e

    alias SetmyInfo.Commons.Config.Application, as: ConfigApplication

    test "every layer overrides the one above it, in the documented order" do
        put_environment(%{
            # Layer: which files load.
            "SMI_PROFILES" => "dev",
            "SMI_OPTIONAL_CONFIG_FILES" => "./test/resources/env/optional.yaml",
            # Layer: ${...} placeholders inside those files.
            "SOME_STRING_VALUE_A" => "from the environment",
            # Layer: value overrides.
            "SMI_SERVER_HOST" => "env.setmy.info",
            "SMI_SERVER_PORT" => "9099",
            "SMI_SERVER_SECURE" => "true"
        })

        argv = [
            "--smi-optional-config-files",
            "./test/resources/cli/optional.yaml",
            "--smi-server-port=9100"
        ]

        app = SetmyInfo.Commons.load(argv)

        # 1. application.yaml
        assert ConfigApplication.get(app, ["smi", "xyz"]) == "abc,def,ghi"

        # 2. application-dev.yaml overrides it (profile selected by SMI_PROFILES)
        assert app.profiles_list == ["dev"]
        assert ConfigApplication.get(app, ["smi", "source"]) == "application-dev.yaml"

        # 3. ${SOME_STRING_VALUE_A} resolved while reading application.yaml
        assert ConfigApplication.get(app, ["a", "h"]) == "from the environment"

        # 4. optional files, environment's then CLI's - CLI wins on the shared key
        assert ConfigApplication.get(app, ["a", "k", "l"]) ==
                 "Some optional value from CLI optional yaml"

        # 5. environment variables override configured values
        assert ConfigApplication.get(app, ["smi", "server", "host"]) == "env.setmy.info"
        assert ConfigApplication.get(app, ["smi", "server", "secure"]) === true

        # 6. CLI options override the environment
        assert ConfigApplication.get(app, ["smi", "server", "port"]) === 9100

        assert app.arguments.errors == []
        assert app.name == "Cli optional Application"
    end

    test "a developer machine with a bare command line lands on the local profile" do
        app = SetmyInfo.Commons.load([])

        assert app.profiles_list == ["local"]
        assert ConfigApplication.get(app, ["smi", "source"]) == "application-local.yaml"
        assert ConfigApplication.get(app, ["smi", "server", "host"]) == "127.0.0.1"
    end
end
