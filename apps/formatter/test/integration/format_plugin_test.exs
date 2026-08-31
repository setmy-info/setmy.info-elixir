defmodule SetmyInfo.Elixir.Formatter.FormatPluginIntegrationTest do
    @moduledoc """
    Integration tier: the plugin driven through `Mix.Tasks.Format` - the real
    caller - over real files on disk, resolved through a real `.formatter.exs`.

    The unit tier calls `format/2` directly with hand-built options, which
    proves the algorithm but not the wiring: that `features/1` claims the right
    extensions, that a `.formatter.exs` naming the plugin actually loads it,
    and that the task rewrites the file rather than just returning a string.
    Those are what break when the plugin is moved between apps or its
    dependency declaration is wrong, and they are what this tier covers.
    """

    use ExUnit.Case, async: false

    @moduletag :integration

    alias Mix.Tasks.Format
    alias SetmyInfo.Elixir.Formatter.FourSpaces

    @two_space "defmodule Subject do\n  def f do\n    :ok\n  end\nend\n"
    @four_space "defmodule Subject do\n    def f do\n        :ok\n    end\nend\n"

    setup do
        dir = Path.join(System.tmp_dir!(), "smi_formatter_it_#{System.unique_integer([:positive])}")
        File.mkdir_p!(dir)
        on_exit(fn -> File.rm_rf(dir) end)

        dot_formatter = Path.join(dir, ".formatter.exs")

        File.write!(
            dot_formatter,
            ~s([plugins: [SetmyInfo.Elixir.Formatter.FourSpaces], inputs: ["*.ex"]])
        )

        {:ok, dir: dir, dot_formatter: dot_formatter}
    end

    test "features/1 claims the extensions mix format dispatches on" do
        assert FourSpaces.features([]) == [extensions: [".ex", ".exs"]]
    end

    test "the task rewrites a file to 4 spaces through the .formatter.exs", context do
        path = Path.join(context.dir, "subject.ex")
        File.write!(path, @two_space)

        Format.run([path, "--dot-formatter", context.dot_formatter])

        assert File.read!(path) == @four_space
    end

    test "--check-formatted rejects 2 spaces and accepts what the task produced", context do
        path = Path.join(context.dir, "subject.ex")
        File.write!(path, @two_space)

        assert_raise Mix.Error, fn ->
            Format.run([path, "--dot-formatter", context.dot_formatter, "--check-formatted"])
        end

        File.write!(path, @four_space)

        assert Format.run([
                 path,
                 "--dot-formatter",
                 context.dot_formatter,
                 "--check-formatted"
               ]) == :ok
    end

    test "formatting is idempotent through the task, not only through format/2", context do
        path = Path.join(context.dir, "subject.ex")
        File.write!(path, @two_space)

        Format.run([path, "--dot-formatter", context.dot_formatter])
        once = File.read!(path)
        Format.run([path, "--dot-formatter", context.dot_formatter])

        assert File.read!(path) == once
    end

    test "heredoc values survive a real round trip through the task", context do
        path = Path.join(context.dir, "subject.ex")

        File.write!(
            path,
            "defmodule Subject do\n  @moduledoc \"\"\"\n  Text\n\n      sample\n  \"\"\"\nend\n"
        )

        Format.run([path, "--dot-formatter", context.dot_formatter])

        assert File.read!(path) ==
                 "defmodule Subject do\n    @moduledoc \"\"\"\n    Text\n\n        sample\n    \"\"\"\nend\n"
    end
end
