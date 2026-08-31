defmodule SetmyInfo.Elixir.Formatter.FormatCommandE2eTest do
    @moduledoc """
    E2E tier: `mix format` as a real operating-system process, the way a
    developer, the pre-commit hook and the CI gate all invoke it.

    This is the only tier that proves the whole chain outside the test VM: the
    `mix` executable resolves the project, reads `.formatter.exs`, finds the
    plugin as a compiled beam on the code path, rewrites the file, and reports
    the exit status the hook and the pipeline actually branch on. The
    integration tier calls `Mix.Tasks.Format` in process, which cannot catch a
    plugin that fails to load - the exact failure this app was split out of
    `commons` to fix.

    Runs against this app's own directory, so no scratch project has to be
    created and compiled first.
    """

    use ExUnit.Case, async: false

    @moduletag :e2e

    @two_space "defmodule Subject do\n  def f do\n    :ok\n  end\nend\n"
    @four_space "defmodule Subject do\n    def f do\n        :ok\n    end\nend\n"

    setup do
        # Inside lib/, so the app's own .formatter.exs inputs would match it too;
        # removed again whatever the test does.
        path = Path.join("lib", "e2e_subject_#{System.unique_integer([:positive])}.ex")
        on_exit(fn -> File.rm(path) end)
        {:ok, path: path}
    end

    defp mix(args), do: System.cmd("mix", args, stderr_to_stdout: true)

    test "the command reformats a 2-space file to 4 spaces", context do
        File.write!(context.path, @two_space)

        assert {_output, 0} = mix(["format", context.path])
        assert File.read!(context.path) == @four_space
    end

    test "--check-formatted exits non-zero on 2 spaces and zero on 4", context do
        File.write!(context.path, @two_space)
        assert {output, status} = mix(["format", "--check-formatted", context.path])
        assert status != 0
        assert output =~ "not formatted"

        File.write!(context.path, @four_space)
        assert {_output, 0} = mix(["format", "--check-formatted", context.path])
    end

    test "the plugin is found with this app alone as the current project", context do
        # The regression that split this app out of `commons`: a plugin compiled
        # into another app is not on the code path here, and mix format then dies
        # with "Formatter plugin ... cannot be found".
        File.write!(context.path, @two_space)

        {output, 0} = mix(["format", context.path])

        refute output =~ "cannot be found"
        assert File.read!(context.path) == @four_space
    end

    test "the app's own sources are formatted, under the strict gate CI uses" do
        {output, status} =
            System.cmd("mix", ["format", "--check-formatted"],
                stderr_to_stdout: true,
                env: [{"FOUR_SPACES_STRICT", "1"}]
            )

        assert status == 0, "apps/formatter is not formatted:\n" <> output
    end
end
