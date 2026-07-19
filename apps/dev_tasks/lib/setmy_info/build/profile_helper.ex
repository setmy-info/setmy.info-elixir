defmodule SetmyInfo.Build.ProfileHelper do
  @moduledoc """
  ADR-0041/ADR-0042 canonical profile validation. Mirrors
  `tools/profile-utils.js` / `scripts/profile_utils.py` one-to-one,
  including staying pure (raises rather than halting the VM), so this stays
  unit-testable in-process the same way.

  YAML, not JSON: the org's real precedent (confirmed on the Python side via
  `python-commons`'s dedicated PyYAML dependency, and here via both real
  Elixir repos using `.yaml` for environment config) makes YAML the natural
  choice, same "ecosystem choice, documented" territory requirements-rules.md
  §6.3 already carves out.
  """

  alias SetmyInfo.Build.WorkspaceHelper

  @canonical_profiles ~w(local dev ci test prelive live)

  @spec canonical_profiles() :: [String.t()]
  def canonical_profiles, do: @canonical_profiles

  @spec require_canonical_profile(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def require_canonical_profile(nil) do
    {:error,
     "Missing profile. Pass --profile <name> or set BUILD_PROFILE. " <>
       "Allowed values (ADR-0041/ADR-0042): #{Enum.join(@canonical_profiles, ", ")}."}
  end

  def require_canonical_profile(value) when value in @canonical_profiles, do: {:ok, value}

  def require_canonical_profile(value) do
    {:error,
     "Invalid profile #{inspect(value)}. Only the ADR-0041 canonical environment names " <>
       "are allowed as profiles (ADR-0042): #{Enum.join(@canonical_profiles, ", ")}."}
  end

  @spec resolve_profile_arg([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_profile_arg(args) do
    {parsed, _rest, _invalid} = OptionParser.parse(args, strict: [profile: :string])
    from_flag = Keyword.get(parsed, :profile)
    require_canonical_profile(from_flag || System.get_env("BUILD_PROFILE"))
  end

  @doc """
  Root profiles/<name>.yaml provides shared defaults; an optional
  per-app profiles/<name>.yaml overrides/extends them - same layering as
  the JS/Python sides' Maven-parent-POM-vs-module-profile analogy.
  """
  @spec resolve_profile_properties(String.t(), String.t()) :: map()
  def resolve_profile_properties(profile, app_dir) do
    root_properties =
      read_profile_yaml(Path.join([WorkspaceHelper.root_dir(), "profiles", "#{profile}.yaml"]))

    app_properties = read_profile_yaml(Path.join([app_dir, "profiles", "#{profile}.yaml"]))

    root_properties
    |> Map.merge(app_properties)
    |> Map.put("profile", profile)
  end

  defp read_profile_yaml(path) do
    if File.exists?(path) do
      case YamlElixir.read_from_file(path) do
        {:ok, data} when is_map(data) -> data
        {:ok, _other} -> %{}
        {:error, reason} -> raise "Invalid profile YAML at #{path}: #{inspect(reason)}"
      end
    else
      %{}
    end
  end
end
