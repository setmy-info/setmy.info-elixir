defmodule SetmyInfo.Commons.Config.ApplicationIntegrationTest do
    @moduledoc """
    Integration tier (ADR-0031: config files, data files and environment
    variables are IT dependencies, not UT ones). Direct port of clj-commons'
    `info.setmy.config.application-it` and python-commons'
    `IntegrationTestApplication`, using the same fixture layout
    (`test/resources`, `test/resources/env`, `test/resources/cli`) and the
    same `SOME_*` placeholder values.

    Runs with `async: false` and with cwd at this app's own directory - Mix
    sets the cwd per umbrella app, which is what makes the two older rows'
    relative `./test/resources` paths work here unchanged.
    """

    use SetmyInfo.Commons.EnvironmentCase, async: false

    @moduletag :integration

    alias SetmyInfo.Commons.Arguments.{Config, Constants}
    alias SetmyInfo.Commons.Config.Application, as: ConfigApplication

    @args_config Config.new("Example parser", Constants.smi_arguments())

    @placeholders %{
        "d" => 123,
        "e" => 123.456,
        "f" => true,
        "g" => false,
        "h" => "A AA AAA",
        "i" => "B BB BBB",
        "j" => "${NON_EXISTING_VALUE}"
    }

    defp application_yaml_a do
        Map.put(@placeholders, "b", Map.put(@placeholders, "c", "application.yaml"))
    end

    describe "init/3 with no environment and no CLI" do
        test "loads application.yaml and the default local profile overlay" do
            app = ConfigApplication.init([], @args_config)

            assert app.profiles_list == ["local"]
            assert app.config_paths == ["./resources", "./test/resources"]

            assert app.default_application_files == [
                              "application.json",
                              "application.yml",
                              "application.yaml"
                          ]

            assert app.application_profiles_file_prefixes == ["application-local"]

            assert app.application_files == [
                              "application.json",
                              "application.yml",
                              "application.yaml",
                              "application-local.json",
                              "application-local.yml",
                              "application-local.yaml"
                          ]

            assert Enum.map(app.applications_files_contents, &elem(&1, 0)) == [
                              "./test/resources/application.yaml",
                              "./test/resources/application-local.yaml"
                          ]
        end

        test "resolves ${ENV_VAR} placeholders into real YAML scalars" do
            app = ConfigApplication.init([], @args_config)

            assert ConfigApplication.get(app, ["a"]) == application_yaml_a()
            assert ConfigApplication.get(app, ["a", "b", "d"]) === 123
            assert ConfigApplication.get(app, ["a", "b", "e"]) === 123.456
            assert ConfigApplication.get(app, ["a", "b", "f"]) === true
            assert ConfigApplication.get(app, ["a", "b", "g"]) === false
        end

        test "an unset placeholder is left literal rather than blanked" do
            app = ConfigApplication.init([], @args_config)

            assert ConfigApplication.get(app, ["a", "j"]) == "${NON_EXISTING_VALUE}"
        end

        test "the profile overlay overrides the base file key by key" do
            app = ConfigApplication.init([], @args_config)

            assert ConfigApplication.get(app, ["smi", "source"]) == "application-local.yaml"
            assert ConfigApplication.get(app, ["smi", "server", "host"]) == "127.0.0.1"
            assert ConfigApplication.get(app, ["smi", "server", "port"]) == 8080
            assert ConfigApplication.get(app, ["smi", "server", "secure"]) == false
            assert app.name == "Local Application"
        end

        test "the default profile can be replaced through opts" do
            app = ConfigApplication.init([], @args_config, default_profiles: [])

            assert app.profiles_list == []
            assert ConfigApplication.get(app, ["smi", "source"]) == "application.yaml"
            assert app.name == "Application 1"
        end
    end

    describe "init/3 with environment profiles and paths" do
        test "SMI_PROFILES, SMI_CONFIG_PATHS and SMI_OPTIONAL_CONFIG_FILES all apply" do
            put_environment(%{
                "SMI_PROFILES" => "dev",
                "SMI_CONFIG_PATHS" => "./test/resources/env",
                "SMI_OPTIONAL_CONFIG_FILES" => "./test/resources/env/optional.yaml"
            })

            app = ConfigApplication.init([], @args_config)

            assert app.env_profiles == ["dev"]
            assert app.profiles_list == ["dev"]
            assert app.config_paths == ["./resources", "./test/resources", "./test/resources/env"]

            assert Enum.map(app.applications_files_contents, &elem(&1, 0)) == [
                              "./test/resources/application.yaml",
                              "./test/resources/application-dev.yaml",
                              "./test/resources/env/application.yaml",
                              "./test/resources/env/optional.yaml"
                          ]

            assert ConfigApplication.get(app, ["name"]) == "./test/resources/env/application.yaml"
            assert ConfigApplication.get(app, ["d", "e", "f"]) == "env/application.yaml"

            assert ConfigApplication.get(app, ["a", "k", "l"]) ==
                              "Some optional value from environment optional yaml"

            assert ConfigApplication.get(app, ["smi", "source"]) == "application-dev.yaml"
            assert ConfigApplication.get(app, ["smi", "server", "host"]) == "dev.api.setmy.info"
            assert ConfigApplication.get(app, ["smi", "server", "port"]) == 9090
            assert app.name == "Optional Application"
        end

        test "SMI_NAME wins over the configured application.name" do
            put_environment(%{"SMI_NAME" => "named-by-environment"})

            assert ConfigApplication.init([], @args_config).name == "named-by-environment"
        end
    end

    describe "init/3 with CLI options over environment" do
        test "CLI profiles, paths and optional files all replace their environment counterparts" do
            put_environment(%{
                "SMI_PROFILES" => "dev",
                "SMI_CONFIG_PATHS" => "./test/resources/env",
                "SMI_OPTIONAL_CONFIG_FILES" => "./test/resources/env/optional.yaml"
            })

            args = [
                "sub-command",
                "--smi-profiles",
                "local",
                "--smi-config-paths",
                "./test/resources/cli",
                "--smi-optional-config-files",
                "./test/resources/cli/optional.yaml"
            ]

            app = ConfigApplication.init(args, @args_config)

            assert app.env_profiles == ["dev"]
            assert app.cli_profiles == ["local"]
            assert app.profiles_list == ["local"]

            assert app.config_paths == [
                              "./resources",
                              "./test/resources",
                              "./test/resources/env",
                              "./test/resources/cli"
                          ]

            assert Enum.map(app.applications_files_contents, &elem(&1, 0)) == [
                              "./test/resources/application.yaml",
                              "./test/resources/application-local.yaml",
                              "./test/resources/env/application.yaml",
                              "./test/resources/cli/application.yaml",
                              "./test/resources/env/optional.yaml",
                              "./test/resources/cli/optional.yaml"
                          ]

            assert ConfigApplication.get(app, ["name"]) == "./test/resources/cli/application.yaml"
            assert ConfigApplication.get(app, ["g", "h", "i"]) == "cli/application.yaml"

            assert ConfigApplication.get(app, ["a", "k", "l"]) ==
                              "Some optional value from CLI optional yaml"

            assert app.name == "Cli optional Application"
            assert app.arguments.arguments == ["sub-command"]
            assert app.arguments.errors == []
        end

        test "--smi-name wins over SMI_NAME" do
            put_environment(%{"SMI_NAME" => "named-by-environment"})

            app = ConfigApplication.init(["--smi-name", "named-by-cli"], @args_config)

            assert app.name == "named-by-cli"
        end
    end

    describe "init/3 value overrides" do
        test "environment variables override configured values, keeping their type" do
            put_environment(%{
                "SMI_SERVER_PORT" => "9099",
                "SMI_SERVER_SECURE" => "true",
                "SMI_API_BASE_URL" => "https://env.setmy.info",
                "SMI_HOSTS" => "gamma, delta"
            })

            app = ConfigApplication.init([], @args_config)

            assert app.environment_overrides == %{
                              ["smi", "server", "port"] => 9099,
                              ["smi", "server", "secure"] => true,
                              ["smi", "apiBaseUrl"] => "https://env.setmy.info",
                              ["smi", "hosts"] => ["gamma", "delta"]
                          }

            assert ConfigApplication.get(app, ["smi", "server", "port"]) === 9099
            assert ConfigApplication.get(app, ["smi", "server", "secure"]) === true
            assert ConfigApplication.get(app, ["smi", "hosts"]) == ["gamma", "delta"]

            # The file layers are kept intact alongside the overridden result.
            assert get_in(app.file_configuration, ["smi", "server", "port"]) == 8080
        end

        test "CLI options override environment variables" do
            put_environment(%{"SMI_SERVER_PORT" => "9099", "SMI_SERVER_HOST" => "env.setmy.info"})

            app = ConfigApplication.init(["--smi-server-port=9100"], @args_config)

            assert app.cli_overrides == %{["smi", "server", "port"] => 9100}
            assert ConfigApplication.get(app, ["smi", "server", "port"]) === 9100
            assert ConfigApplication.get(app, ["smi", "server", "host"]) == "env.setmy.info"
        end

        test "an override flag is not reported as an unknown option" do
            app = ConfigApplication.init(["--smi-server-port", "9100"], @args_config)

            assert app.arguments.errors == []
        end

        test "a flag that overrides nothing is still reported" do
            app = ConfigApplication.init(["--smi-server-timeout", "30"], @args_config)

            assert app.arguments.errors == [{:unknown_option, "--smi-server-timeout"}]
        end

        test "keys outside the smi root are not overridable by default" do
            put_environment(%{"NAME" => "hijacked"})

            app = ConfigApplication.init([], @args_config)

            assert ConfigApplication.get(app, ["name"]) == "./test/resources/application.yaml"
        end

        test "override_root_keys: nil opts every root in" do
            put_environment(%{"NAME" => "chosen"})

            app = ConfigApplication.init([], @args_config, override_root_keys: nil)

            assert ConfigApplication.get(app, ["name"]) == "chosen"
        end
    end

    describe "init/3 with nothing to load" do
        test "an empty config path set yields an empty configuration named default" do
            app = ConfigApplication.init([], @args_config, config_paths: ["./test/resources/nowhere"])

            assert app.applications_files_contents == []
            assert app.merged_configuration == %{}
            assert app.name == "default"
        end
    end
end
