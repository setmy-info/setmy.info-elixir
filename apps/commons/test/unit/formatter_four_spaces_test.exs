defmodule SetmyInfo.Elixir.Formatter.FourSpacesTest do
    @moduledoc """
    The umbrella's `mix format` plugin: 4-space nesting, alignment and string
    values untouched, idempotent.
    """

    use ExUnit.Case, async: true

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

    defp module_doc(source) do
        {:defmodule, _, [_, [do: {:@, _, [{:moduledoc, _, [doc]}]}]]} = Code.string_to_quoted!(source)
        doc
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
