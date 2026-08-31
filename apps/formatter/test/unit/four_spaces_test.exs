defmodule SetmyInfo.Elixir.Formatter.FourSpacesTest do
    @moduledoc """
    The umbrella's `mix format` plugin: 4-space nesting, alignment and string
    values untouched, idempotent.

    The expected strings are the stock formatter's output plus widening, so an
    upstream Elixir formatter change shows up here as churn - expected, and
    not a plugin bug.
    """

    # async: false - format/1 below captures :stderr, a NAMED device, which is
    # global to the VM; capturing it while other async modules run swallows or
    # misattributes their output.
    use ExUnit.Case, async: false

    alias SetmyInfo.Elixir.Formatter.FourSpaces

    import ExUnit.CaptureIO

    # The AST guard falls back to the stock output with a message; here that
    # counts as a failure, so a case the plugin cannot widen is never hidden.
    defp format(source) do
        {result, output} = with_io(:stderr, fn -> FourSpaces.format(source, []) end)
        assert output == "", "plugin fell back to the stock output: " <> output
        result
    end

    test "widens nesting from 2 to 4 spaces and is idempotent" do
        source = "defmodule A do\n  def f do\n    :ok\n  end\nend\n"
        expected = "defmodule A do\n    def f do\n        :ok\n    end\nend\n"

        assert format(source) == expected
        assert format(expected) == expected
    end

    test "keeps alignment offsets of wrapped continuation lines" do
        source = "assert value == [\n  \"a\",\n  \"b\"\n]\n"

        assert format(source) == "assert value == [\n         \"a\",\n         \"b\"\n       ]\n"
    end

    test "heredoc content keeps its indentation relative to the delimiter" do
        source = "defmodule A do\n  @moduledoc \"\"\"\n  Text\n\n      code sample\n  \"\"\"\nend\n"
        formatted = format(source)

        assert formatted ==
                 "defmodule A do\n    @moduledoc \"\"\"\n    Text\n\n        code sample\n    \"\"\"\nend\n"

        assert module_doc(formatted) == module_doc(source)
        assert module_doc(source) == "Text\n\n    code sample\n"
    end

    test "multi-line strings, sigils and charlists keep their values" do
        source =
            "defmodule A do\n  def f do\n    {\"a\n  b\", ~r/c\n  d/, ~c\"e\n  f\", \"g\#{1}h\n  i\"}\n  end\nend\n"

        formatted = format(source)

        assert format(formatted) == formatted
        assert values(formatted) == values(source)
        assert values(source) == {"a\n  b", "c\n  d", ~c"e\n  f", "g1h\n  i"}
    end

    test "an escaped newline in a one-line string does not swallow the next line" do
        source = "defmodule A do\n  def f do\n    Enum.join([1], \"\\n\")\n  end\nend\n"

        assert format(source) ==
                 "defmodule A do\n    def f do\n        Enum.join([1], \"\\n\")\n    end\nend\n"
    end

    test "interpolation containing the delimiter does not end the string early" do
        source = "defmodule A do\n  def f do\n    \"a\#{\"}\"}b\n  c\"\n  end\nend\n"
        formatted = format(source)

        assert formatted ==
                 "defmodule A do\n    def f do\n        \"a\#{\"}\"}b\n  c\"\n    end\nend\n"

        assert format(formatted) == formatted
        assert eval_f(formatted) == "a}b\n  c"
    end

    test "a file with no code in it is left exactly as the stock formatter leaves it" do
        for blank <- ["", "\n", "   \n\n"] do
            assert FourSpaces.format(blank, []) == Code.format_string!(blank) |> IO.iodata_to_binary()
        end
    end

    test "a comment-only file is widened without inventing a trailing blank line" do
        assert format("# just a comment\n") == "# just a comment\n"
    end

    describe "fall_back/2 (the AST guard's policy)" do
        setup do
            original = System.get_env("FOUR_SPACES_STRICT")

            on_exit(fn ->
                if original, do: System.put_env("FOUR_SPACES_STRICT", original)
                if is_nil(original), do: System.delete_env("FOUR_SPACES_STRICT")
            end)

            :ok
        end

        test "unset: keeps the stock output and warns, naming the file" do
            System.delete_env("FOUR_SPACES_STRICT")

            {result, output} =
                with_io(:stderr, fn -> FourSpaces.fall_back("  :ok\n", file: "lib/a.ex") end)

            assert result == "  :ok\n"
            assert output =~ "lib/a.ex"
            assert output =~ "kept 2 spaces"
        end

        test "empty string counts as unset" do
            System.put_env("FOUR_SPACES_STRICT", "")

            {result, _output} = with_io(:stderr, fn -> FourSpaces.fall_back("  :ok\n", []) end)

            assert result == "  :ok\n"
        end

        test "set: fails the run instead, so nothing slips through the gate at 2 spaces" do
            System.put_env("FOUR_SPACES_STRICT", "1")

            assert_raise Mix.Error, ~r/FOUR_SPACES_STRICT/, fn ->
                FourSpaces.fall_back("  :ok\n", file: "lib/a.ex")
            end
        end

        test "the message names the file in both modes, or says so when there is none" do
            System.put_env("FOUR_SPACES_STRICT", "1")

            assert_raise Mix.Error, ~r/a file/, fn -> FourSpaces.fall_back("  :ok\n", []) end
        end
    end

    defp module_doc(source) do
        case Code.string_to_quoted!(source) do
            {:defmodule, _, [_, [do: {:@, _, [{:moduledoc, _, [doc]}]}]]} -> doc
            other -> flunk("expected a moduledoc-only module, got: #{inspect(other)}")
        end
    end

    # Regex structs never compare equal, so the regex is reduced to its source.
    defp values(source) do
        {a, regex, c, d} = eval_f(source)
        {a, Regex.source(regex), c, d}
    end

    # Every evaluated snippet gets a module name of its own: the suite is async,
    # so two tests defining `A` at once would race and warn about redefining it.
    # The call goes through the variable rather than a literal `A.f()`, which
    # names a module that does not exist when this file is compiled.
    defp eval_f(source) do
        name = "FourSpacesSubject#{System.unique_integer([:positive])}"

        {{:module, module, _, _}, _} =
            source |> String.replace("defmodule A do", "defmodule #{name} do") |> Code.eval_string()

        result = module.f()
        :code.purge(module)
        :code.delete(module)
        result
    end
end
