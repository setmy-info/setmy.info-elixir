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
# test fixtures - are unchanged. The continuation lines of an ordinary
# multi-line string, charlist or sigil ARE the value, so they are copied
# byte for byte (found through the AST, not by guessing at quotes). As a last
# line of defence the result must parse to the same AST as the stock output;
# if it does not, the stock output is used for that file and a warning printed.
#
# A compiled module of the commons app (apps/commons/formatter/, an extra
# elixirc path that is not in the Hex package) rather than a script evaluated
# from .formatter.exs: `mix format` caches the evaluated .formatter.exs under
# _build/ and loads plugins from the compiled project, so this is the only
# form that is found reliably on every run.
defmodule SetmyInfo.Elixir.Formatter.FourSpaces do
    @behaviour Mix.Tasks.Format

    @heredocs [~s("""), ~s(''')]
    @stock 2
    @wanted 4

    @impl true
    def features(_opts), do: [extensions: [".ex", ".exs"]]

    @impl true
    def format(contents, opts) do
        stock = contents |> Code.format_string!(opts) |> IO.iodata_to_binary()

        widened =
            stock
            |> String.split("\n")
      |> Enum.with_index(1)
            |> reindent(protected_lines(stock), [{0, 0}], nil, [])
            |> Enum.join("\n")
      |> String.replace(~r/\n*\z/, "\n")

        if ast(widened) == ast(stock) do
            widened
        else
            Mix.shell().error(
                "formatter_indent: widening changed #{opts[:file] || "a file"}, kept 2 spaces"
            )

            stock
        end
    end

    defp ast(source) do
        source
        |> Code.string_to_quoted!(columns: false)
        |> Macro.prewalk(fn
            {form, _meta, args} -> {form, [], args}
            other -> other
        end)
    end

    # Line numbers that are the inside of a multi-line string, charlist or
    # sigil that is not a heredoc: lines after the one the literal starts on.
    defp protected_lines(stock) do
        stock
        |> Code.string_to_quoted!(
            columns: true,
            token_metadata: true,
            literal_encoder: &{:ok, {:__literal__, &2, [&1]}}
        )
        |> Macro.prewalk(MapSet.new(), fn
            {:__literal__, meta, [value]} = node, acc when is_binary(value) or is_list(value) ->
                {node, protect(acc, meta, literal_newlines(value))}

            {:<<>>, meta, parts} = node, acc ->
                {node,
                 protect(
                     acc,
                     meta,
                     Enum.sum(for part <- parts, is_binary(part), do: literal_newlines(part))
                 )}

            {sigil, meta, [{:<<>>, _, parts}, _mods]} = node, acc when is_atom(sigil) ->
                if String.starts_with?(Atom.to_string(sigil), "sigil_"),
                    do:
                        {node,
                         protect(
                             acc,
                             meta,
                             Enum.sum(for part <- parts, is_binary(part), do: literal_newlines(part))
                         )},
                    else: {node, acc}

            node, acc ->
                {node, acc}
        end)
        |> elem(1)
    end

    defp protect(acc, meta, newlines) do
        delimiter = meta[:delimiter]

        if newlines > 0 and is_binary(delimiter) and delimiter not in @heredocs and meta[:line] do
            Enum.into((meta[:line] + 1)..(meta[:line] + newlines), acc)
        else
            acc
        end
    end

    defp literal_newlines(value) when is_binary(value),
        do: value |> String.graphemes() |> Enum.count(&(&1 == "\n"))

    defp literal_newlines(value) when is_list(value), do: Enum.count(value, &(&1 == ?\n))

    # stack: [{stock_indent, wanted_indent}] of the enclosing lines, innermost
    # first; heredoc: nil or {delimiter, shift} while inside one.
    defp reindent([], _protected, _stack, _heredoc, acc), do: Enum.reverse(acc)

    defp reindent([{"", _} | rest], protected, stack, heredoc, acc),
        do: reindent(rest, protected, stack, heredoc, ["" | acc])

    defp reindent([{line, _} | rest], protected, stack, {delim, shift} = heredoc, acc) do
        out = String.duplicate(" ", shift) <> line

        if String.starts_with?(String.trim_leading(line), delim),
            do: reindent(rest, protected, stack, nil, [out | acc]),
            else: reindent(rest, protected, stack, heredoc, [out | acc])
    end

    defp reindent([{line, number} | rest], protected, stack, nil, acc) do
        if MapSet.member?(protected, number),
            do: reindent(rest, protected, stack, nil, [line | acc]),
            else: reindent_code(line, rest, protected, stack, acc)
    end

    defp reindent_code(line, rest, protected, stack, acc) do
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
            nil -> reindent(rest, protected, stack, nil, [out | acc])
            delim -> reindent(rest, protected, stack, {delim, wanted - indent}, [out | acc])
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
