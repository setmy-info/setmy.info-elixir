defmodule SetmyInfo.Build.WorkspaceHelper do
  @moduledoc """
  Umbrella app discovery + topological sort. Mirrors
  `tools/workspace-utils.js` / `scripts/workspace_utils.py` one-to-one -
  every custom Mix task in this app that needs to fan a phase out across
  `apps/*` imports this rather than re-deriving discovery/ordering itself.

  Assumes it is invoked with the current working directory at the umbrella
  root (true for every `mix <task>` invocation used by this build system) -
  same cwd assumption `scripts/workspace_utils.py`'s `ROOT_DIR` makes.
  """

  @type app_info :: %{name: atom(), path: String.t(), local_deps: [atom()]}

  @spec root_dir() :: String.t()
  def root_dir, do: File.cwd!()

  @doc "Every apps/*/mix.exs member, with its declared in_umbrella deps."
  @spec discover_apps() :: [app_info()]
  def discover_apps do
    root = root_dir()

    root
    |> Path.join("apps/*/mix.exs")
    |> Path.wildcard()
    |> Enum.map(&load_app_info/1)
    |> Enum.sort_by(& &1.name)
  end

  defp load_app_info(mix_exs_path) do
    app_dir = Path.dirname(mix_exs_path)
    app_name = app_dir |> Path.basename() |> String.to_atom()

    config = Mix.Project.in_project(app_name, app_dir, fn _module -> Mix.Project.config() end)

    local_deps =
      config
      |> Keyword.get(:deps, [])
      |> Enum.filter(&umbrella_dep?/1)
      |> Enum.map(&elem(&1, 0))

    %{name: app_name, path: app_dir, local_deps: local_deps}
  end

  defp umbrella_dep?({_name, opts}) when is_list(opts),
    do: Keyword.get(opts, :in_umbrella) == true

  defp umbrella_dep?({_name, _requirement, opts}) when is_list(opts),
    do: Keyword.get(opts, :in_umbrella) == true

  defp umbrella_dep?(_), do: false

  @doc """
  Dependencies before dependents. `reverse: true` reverses the order
  (dependents before dependencies) - used for `clean`, same reasoning as the
  JS side's `reverseLifecycles` set.
  """
  @spec sort_topologically([app_info()], keyword()) :: [app_info()]
  def sort_topologically(apps, opts \\ []) do
    sorted = do_sort(Map.new(apps, &{&1.name, &1}), [])
    if Keyword.get(opts, :reverse, false), do: Enum.reverse(sorted), else: sorted
  end

  defp do_sort(pending, sorted) when map_size(pending) == 0, do: Enum.reverse(sorted)

  defp do_sort(pending, sorted) do
    ready =
      pending
      |> Map.values()
      |> Enum.filter(fn app -> Enum.all?(app.local_deps, &(not Map.has_key?(pending, &1))) end)
      |> Enum.sort_by(& &1.name)

    if ready == [] do
      raise "Circular umbrella dependency detected among: #{inspect(Map.keys(pending))}"
    end

    remaining = Enum.reduce(ready, pending, fn app, acc -> Map.delete(acc, app.name) end)
    do_sort(remaining, Enum.reverse(ready) ++ sorted)
  end

  @doc "Convenience: discover_apps/0 already topologically sorted."
  @spec apps_in_order(keyword()) :: [app_info()]
  def apps_in_order(opts \\ []) do
    discover_apps() |> sort_topologically(opts)
  end

  # dev_tasks (this app) hosts the phase-runner tooling itself, not a demo
  # module - it has no resources/, no test/{unit,integration,e2e}/ tier, no
  # [tool.server]-equivalent port, so every phase fan-out excludes it the
  # same way tools/*.js/scripts/*.py are never fanned out over as if they
  # were workspace packages themselves.
  @tooling_apps [:dev_tasks]

  @doc "apps_in_order/1, excluding this build system's own tooling app(s)."
  @spec demo_apps_in_order(keyword()) :: [app_info()]
  def demo_apps_in_order(opts \\ []) do
    apps_in_order(opts) |> Enum.reject(&(&1.name in @tooling_apps))
  end
end
