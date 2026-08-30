# `mix format` plugin: the stock Elixir formatter has no indentation-width
# option and always emits 2 spaces. This project's style is 4 (.editorconfig),
# so every .ex/.exs file goes through the stock formatter and then has its
# indentation widened. Because it is a plugin, `mix format --check-formatted`
# (pre-commit hook, CI quality gate, editors) verifies the same 4-space form.
#
# The stock output mixes two kinds of indentation: NESTING, always exactly +2
# per level (a `do` block, a `->` clause, a wrapped argument list), and
# ALIGNMENT, a continuation line placed at an arbitrary column offset from the
# statement it belongs to (`assert x == [` puts the elements 9 columns in; a
# wrapped `@spec` aligns under its opening paren). Only nesting steps are
# widened (2 -> 4); alignment offsets are carried over unchanged, otherwise a
# wrapped line at column 70 would end up at 140.
#
# Inside a heredoc (`"""` / `'''`) the content is shifted by exactly what its
# delimiter line was shifted, so string values - docs, code samples in docs,
# test fixtures - are unchanged.
#
# Loaded with `Code.require_file` from the root and per-app .formatter.exs
# files, so it needs no app, no dependency, and no compile step.
defmodule SetmyInfo.Elixir.Formatter.FourSpaces do
  @behaviour Mix.Tasks.Format

  @heredocs [~s("""), ~s(''')]
  @stock 2
  @wanted 4

  @impl true
  def features(_opts), do: [extensions: [".ex", ".exs"]]

  @impl true
  def format(contents, opts) do
    contents
    |> Code.format_string!(opts)
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> reindent([{0, 0}], nil, [])
    |> Enum.join("\n")
    |> String.replace(~r/\n*\z/, "\n")
  end

  # stack: [{stock_indent, wanted_indent}] of the enclosing lines, innermost
  # first; heredoc: nil or {delimiter, shift} while inside one.
  defp reindent([], _stack, _heredoc, acc), do: Enum.reverse(acc)

  defp reindent(["" | rest], stack, heredoc, acc), do: reindent(rest, stack, heredoc, ["" | acc])

  defp reindent([line | rest], stack, {delim, shift} = heredoc, acc) do
    out = String.duplicate(" ", shift) <> line

    if String.starts_with?(String.trim_leading(line), delim),
      do: reindent(rest, stack, nil, [out | acc]),
      else: reindent(rest, stack, heredoc, [out | acc])
  end

  defp reindent([line | rest], stack, nil, acc) do
    {indent, body} = split_indent(line)
    stack = Enum.drop_while(stack, fn {stock, _} -> stock > indent end)
    [{stock, wanted} | _] = stack

    wanted =
      cond do
        indent == stock -> wanted
        indent - stock == @stock -> wanted + @wanted
        true -> wanted + (indent - stock)
      end

    stack = if indent == stock, do: stack, else: [{indent, wanted} | stack]
    out = String.duplicate(" ", wanted) <> body

    case heredoc_opened(body) do
      nil -> reindent(rest, stack, nil, [out | acc])
      delim -> reindent(rest, stack, {delim, wanted - indent}, [out | acc])
    end
  end

  defp split_indent(line) do
    body = String.trim_leading(line, " ")
    {String.length(line) - String.length(body), body}
  end

  # A heredoc opens when its delimiter ends a code line (`@doc """`, `~S"""`,
  # `x = '''`). Comments are skipped so a `"""` mentioned in one is inert.
  defp heredoc_opened("#" <> _), do: nil
  defp heredoc_opened(body), do: Enum.find(@heredocs, &String.ends_with?(body, &1))
end
