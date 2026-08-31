defmodule SetmyInfo.Commons.Config.OverridesTest do
    @moduledoc """
    Unit tier (ADR-0031: in-memory only). The override layer is exercised
    through `collect/4`'s injected lookup rather than the real environment -
    reading real environment variables is an integration-tier dependency, and
    the resolution logic itself is pure.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.Commons.Config.Overrides

    @config %{
        "name" => "top level",
        "smi" => %{
            "xyz" => "abc,def,ghi",
            "apiBaseUrl" => "https://api.setmy.info",
            "hosts" => ["alpha", "beta"],
            "server" => %{"host" => "localhost", "port" => 8080, "secure" => false}
        }
    }

    defp lookup(values), do: fn name -> Map.get(values, name) end

    defp environment_collect(config, root_keys, values) do
        Overrides.collect(config, root_keys, &Overrides.environment_variable_names/1, lookup(values))
    end

    describe "leaf_paths/2" do
        test "finds every non-map leaf under the allowed roots" do
            assert Enum.sort(Overrides.leaf_paths(@config, ["smi"])) == [
                     ["smi", "apiBaseUrl"],
                     ["smi", "hosts"],
                     ["smi", "server", "host"],
                     ["smi", "server", "port"],
                     ["smi", "server", "secure"],
                     ["smi", "xyz"]
                   ]
        end

        test "nil root_keys allows every root" do
            assert ["name"] in Overrides.leaf_paths(@config, nil)
        end

        test "a root key that is not allowed contributes nothing" do
            assert Overrides.leaf_paths(@config, ["nope"]) == []
        end
    end

    describe "name derivation" do
        test "environment variable names cover both the split and run-together forms" do
            assert Overrides.environment_variable_names(["smi", "server", "port"]) == [
                     "SMI_SERVER_PORT"
                   ]

            assert Overrides.environment_variable_names(["smi", "apiBaseUrl"]) == [
                     "SMI_API_BASE_URL",
                     "SMI_APIBASEURL"
                   ]
        end

        test "CLI option names cover both forms" do
            assert Overrides.cli_option_names(["smi", "server", "port"]) == ["--smi-server-port"]

            assert Overrides.cli_option_names(["smi", "apiBaseUrl"]) == [
                     "--smi-api-base-url",
                     "--smi-apibaseurl"
                   ]
        end
    end

    describe "collect/4 type coercion" do
        test "an override keeps the type of the value it replaces" do
            overrides =
                environment_collect(@config, ["smi"], %{
                    "SMI_SERVER_PORT" => "9090",
                    "SMI_SERVER_SECURE" => "yes",
                    "SMI_SERVER_HOST" => "example.org",
                    "SMI_HOSTS" => "gamma, delta"
                })

            assert overrides == %{
                     ["smi", "server", "port"] => 9090,
                     ["smi", "server", "secure"] => true,
                     ["smi", "server", "host"] => "example.org",
                     ["smi", "hosts"] => ["gamma", "delta"]
                   }
        end

        test "an unparseable value for a typed key raises, naming the variable and the path" do
            # One loud policy for every type: an override that silently kept the
            # configured value would hide the typo that broke it.
            error =
                assert_raise ArgumentError, fn ->
                    environment_collect(@config, ["smi"], %{"SMI_SERVER_PORT" => "not-a-number"})
                end

            assert error.message =~ "SMI_SERVER_PORT"
            assert error.message =~ "smi.server.port"
            assert error.message =~ "not an integer"
        end

        test "the run-together form resolves when the split form is unset" do
            overrides = environment_collect(@config, ["smi"], %{"SMI_APIBASEURL" => "https://x"})

            assert overrides == %{["smi", "apiBaseUrl"] => "https://x"}
        end

        test "the split form wins when both are set" do
            values = %{"SMI_API_BASE_URL" => "https://split", "SMI_APIBASEURL" => "https://flat"}

            assert environment_collect(@config, ["smi"], values) ==
                     %{["smi", "apiBaseUrl"] => "https://split"}
        end
    end

    describe "collect/4 scoping" do
        test "keys outside the allowed roots are never overridden" do
            assert environment_collect(@config, ["smi"], %{"NAME" => "hijacked"}) == %{}
        end

        test "nil root_keys opts every root in, Spring Boot style" do
            assert environment_collect(@config, nil, %{"NAME" => "chosen"}) ==
                     %{["name"] => "chosen"}
        end

        test "a key absent from the configuration is not invented" do
            assert environment_collect(@config, ["smi"], %{"SMI_SERVER_TIMEOUT" => "30"}) == %{}
        end
    end

    describe "cli_overrides/3 and apply_overrides/2" do
        test "CLI flags resolve against the same paths and write back into the map" do
            argv = ["--smi-server-port", "9091", "--smi-api-base-url=https://cli"]

            overrides = Overrides.cli_overrides(@config, argv, ["smi"])

            assert overrides == %{
                     ["smi", "server", "port"] => 9091,
                     ["smi", "apiBaseUrl"] => "https://cli"
                   }

            applied = Overrides.apply_overrides(@config, overrides)

            assert get_in(applied, ["smi", "server", "port"]) == 9091
            assert get_in(applied, ["smi", "apiBaseUrl"]) == "https://cli"
            assert get_in(applied, ["smi", "server", "host"]) == "localhost"
            assert applied["name"] == "top level"
        end
    end

    describe "all_cli_option_names/2" do
        test "lists every flag that could override something" do
            names = Overrides.all_cli_option_names(@config, ["smi"])

            assert "--smi-server-port" in names
            assert "--smi-api-base-url" in names
            assert "--smi-apibaseurl" in names
            refute "--name" in names
        end
    end
end
