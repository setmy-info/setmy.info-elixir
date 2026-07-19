defmodule SetmyInfo.Build.WorkspaceHelperTest do
  @moduledoc """
  Unit tests for WorkspaceHelper's topological sort - pure in-process
  function calls, no subprocess, no filesystem beyond the in-memory app
  maps built here. Mirrors the JS/Python sides' own workspace-utils
  topo-sort coverage (order + circular-dependency detection).
  """

  use ExUnit.Case, async: true

  alias SetmyInfo.Build.WorkspaceHelper

  defp app(name, deps), do: %{name: name, path: "/tmp/#{name}", local_deps: deps}

  test "sorts dependencies before dependents" do
    a = app(:a, [])
    b = app(:b, [])
    c = app(:c, [:a, :b])
    d = app(:d, [:c])

    sorted = WorkspaceHelper.sort_topologically([d, c, b, a]) |> Enum.map(& &1.name)

    assert Enum.find_index(sorted, &(&1 == :a)) < Enum.find_index(sorted, &(&1 == :c))
    assert Enum.find_index(sorted, &(&1 == :b)) < Enum.find_index(sorted, &(&1 == :c))
    assert Enum.find_index(sorted, &(&1 == :c)) < Enum.find_index(sorted, &(&1 == :d))
  end

  test "independent apps sort alphabetically" do
    sorted =
      WorkspaceHelper.sort_topologically([app(:z, []), app(:a, [])]) |> Enum.map(& &1.name)

    assert sorted == [:a, :z]
  end

  test "reverse: true reverses the final order" do
    a = app(:a, [])
    b = app(:b, [:a])

    assert WorkspaceHelper.sort_topologically([a, b], reverse: true) |> Enum.map(& &1.name) ==
             [:b, :a]
  end

  test "circular dependency raises" do
    a = app(:a, [:b])
    b = app(:b, [:a])

    assert_raise RuntimeError, ~r/Circular/, fn ->
      WorkspaceHelper.sort_topologically([a, b])
    end
  end
end
