defmodule SetmyInfo.Build.ProfileHelperTest do
  use ExUnit.Case, async: true

  alias SetmyInfo.Build.ProfileHelper

  test "accepts every canonical profile" do
    for name <- ProfileHelper.canonical_profiles() do
      assert ProfileHelper.require_canonical_profile(name) == {:ok, name}
    end
  end

  test "rejects missing profile" do
    assert {:error, message} = ProfileHelper.require_canonical_profile(nil)
    assert message =~ "Missing profile"
  end

  test "rejects non-canonical profile" do
    assert {:error, message} = ProfileHelper.require_canonical_profile("staging")
    assert message =~ "Invalid profile"
  end

  test "resolve_profile_arg reads --profile flag" do
    assert ProfileHelper.resolve_profile_arg(["--profile", "dev"]) == {:ok, "dev"}
  end

  test "resolve_profile_arg falls back to BUILD_PROFILE env" do
    System.put_env("BUILD_PROFILE", "ci")
    on_exit(fn -> System.delete_env("BUILD_PROFILE") end)

    assert ProfileHelper.resolve_profile_arg([]) == {:ok, "ci"}
  end
end
