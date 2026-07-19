defmodule Mix.Tasks.Resources do
  use Mix.Task

  @shortdoc "Resource filtering (§6): ${propertyName} substitution from profiles/<name>.yaml"

  @moduledoc """
  Resources phase (§2 row 6, "gate"; §6 in full). Text-level,
  format-agnostic `${propertyName}` substitution from the active profile -
  works unchanged on JSON, YAML, XML, .env, or plain text, the same way
  Maven resource filtering does. Direct mirror of `tools/resources.js` /
  `scripts/resources.py`, including the "no resources/ dir = silent no-op"
  rule (§6.5) and the "unresolved token stays literal + warns" rule (§6.4).

  Output goes to `priv/resources/<profile>/` per app - the release-safe,
  `:code.priv_dir/1`-accessible convention, same role `dist/resources` plays
  on the JS/Python sides.

      mix resources --profile ci
  """

  alias SetmyInfo.Build.{ProfileHelper, WorkspaceHelper}

  @impl Mix.Task
  def run(args) do
    case ProfileHelper.resolve_profile_arg(args) do
      {:error, message} ->
        Mix.raise(message)

      {:ok, profile} ->
        Enum.each(WorkspaceHelper.demo_apps_in_order(), &filter_app(&1, profile))
    end
  end

  defp filter_app(app, profile) do
    resources_dir = Path.join(app.path, "resources")

    if File.dir?(resources_dir) do
      out_dir = Path.join([app.path, "priv", "resources", profile])
      properties = ProfileHelper.resolve_profile_properties(profile, app.path)

      File.rm_rf!(out_dir)
      copy_and_filter(resources_dir, out_dir, properties, app.name, profile)

      Mix.shell().info(
        "Filtered resources for #{app.name} with profile #{inspect(profile)} into #{out_dir}"
      )
    else
      Mix.shell().info("No resources directory for #{app.name}, skipping")
    end
  end

  defp copy_and_filter(source_dir, target_dir, properties, app_name, profile) do
    File.mkdir_p!(target_dir)

    source_dir
    |> File.ls!()
    |> Enum.each(fn entry ->
      source_path = Path.join(source_dir, entry)
      target_path = Path.join(target_dir, entry)

      if File.dir?(source_path) do
        copy_and_filter(source_path, target_path, properties, app_name, profile)
      else
        content = File.read!(source_path)
        File.write!(target_path, filter_content(content, entry, properties, app_name, profile))
      end
    end)
  end

  @token_pattern ~r/\$\{([^}]+)\}/

  defp filter_content(content, file_name, properties, app_name, profile) do
    Regex.replace(@token_pattern, content, fn match, key ->
      case Map.fetch(properties, key) do
        {:ok, value} ->
          to_string(value)

        :error ->
          Mix.shell().info(
            "Warning: #{app_name}/resources/#{file_name} references unresolved property " <>
              "\"\#{#{key}}\" for profile #{inspect(profile)}"
          )

          match
      end
    end)
  end
end
